#!/usr/bin/env sh

prompt() 
{
    printf "%s" "$1"
    while read -r VAR ; do
        if echo "$VAR" | grep -Eqx "$3" ; then
            eval "$2=$VAR"
            break
        else
            printf "Invalid input! Please try again\n"
        fi
    done
}

setup_disk() 
{
    echo "Available disks:"
    lsblk -dn -e 2,7,11 -p -o NAME,SIZE | column
    prompt "Installation drive: " DISK "$(lsblk -dn -e 2,7,11 -p -o NAME)"

}

grub_bios()
{
    prompt "GRUB drive: " GRUB "$(lsblk -dn -e 2,7,11 -p -o NAME)"
}

grub_uefi()
{
    echo "UEFI will use bootctl. Continuing install..."
}

crypt_swap()
{
    MAX="$(lsblk -dn -e 2,7,11 -b -o SIZE "$DISK")"
    echo "RAM: "$(free -h | awk 'FNR == 2 {print $2}')
    printf "Swap size (e.g. 2G): "

    while read -r SWAPSIZE ; do
        if [ "$MAX" -gt "$(echo "$SWAPSIZE" | numfmt --from=iec)" ] && [ "$(echo "$SWAPSIZE" | numfmt --from=iec)" -gt 0 ] ; then
            break
        else
            printf "Invalid input! Please try again\n"
        fi
    done
}

set_swap()
{
    while [ 1 ]; do
        MAX="$(lsblk -dn -e 2,7,11 -b -o SIZE "$DISK")"
        echo "RAM: "$(free -h | awk 'FNR == 2 {print $2}')
        read -p "Swap size in GB (e.g. 2): " SWAP;
        if [ $SWAP ]; then
            break;
        fi
    done
}

set_hostname()
{
    while [ 1 ]; do
        read -p "Preferred hostname: " HOST_NAME;
        if [ "$HOST_NAME" ]; then
            break;
        fi
    done
}

bios_cryptpartitioning() 
{
    timedatectl set-ntp true
    
    parted -s --align optimal -- "$DISK" mklabel msdos \
        mkpart primary ext4 1MiB 513MiB \
        set 1 boot on \
        mkpart primary ext4 513MiB 100%

    mkfs.ext4 -F "${DISK}1"
}

uefi_cryptpartitioning() 
{
    timedatectl set-ntp true

    parted -s --align optimal -- "$DISK" mklabel gpt \
        mkpart ESP fat32 1MiB 513MiB \
        set 1 boot on \
        mkpart primary ext4 513MiB 100%

    mkfs.vfat -F32 "${DISK}1"
}

bios_partitioning()
{
    timedatectl set-ntp true
    
    parted -s --align optimal -- "$DISK" mklabel msdos \
        mkpart primary linux-swap 1MiB "${SWAP}GB" \
        mkpart primary ext4 "${SWAP}GB" 100%

    mkfs.ext4 -F "${DISK}2"
    mkswap "${DISK}1"
    swapon "${DISK}1"

    mount "${DISK}2" /mnt
}

uefi_partitioning()
{
    timedatectl set-ntp true

    NEW=$(echo "$SWAP" .5 | awk '{ printf "%f", $1 + $2 }' | sed '/\./ s/\.\{0,1\}0\{1,\}$//')

    parted -s --align optimal -- "$DISK" mklabel gpt \
        mkpart ESP fat32 1MiB 513MiB \
        set 1 boot on \
        mkpart primary linux-swap 513MiB "${NEW}GB" \
        mkpart primary ext4 "${NEW}GB" 100%

    mkfs.vfat -F32 "${DISK}1"
    mkswap "${DISK}2"
    swapon "${DISK}2"
    mkfs.ext4 -F "${DISK}3"

    mount "${DISK}3" /mnt
    mkdir -p /mnt/boot
    mount "${DISK}1" /mnt/boot
}

crypt_setup()
{
    cryptsetup --verbose --cipher aes-xts-plain64 --key-size 512 --hash sha512 --iter-time 5000 --use-random --batch-mode luksFormat "${DISK}2"
    cryptsetup luksOpen "${DISK}2" luks

    pvcreate /dev/mapper/luks
    vgcreate vg0 /dev/mapper/luks
    lvcreate --size "$SWAPSIZE" vg0 --name swap
    lvcreate -l +100%FREE vg0 --name root

    mkfs.ext4 /dev/mapper/vg0-root
    mkswap /dev/mapper/vg0-swap

    mount /dev/mapper/vg0-root /mnt
    swapon /dev/mapper/vg0-swap
    mkdir /mnt/boot
    mount "${DISK}1" /mnt/boot

}

system_install()
{
    DEVID=$(blkid -s PARTUUID -o value "${DISK}3")
    DEVIDC=$(blkid -s UUID -o value "${DISK}2")

    pacstrap /mnt base base-devel

    genfstab -pU /mnt >> /mnt/etc/fstab

    arch-chroot /mnt pacman -S reflector --noconfirm
    arch-chroot /mnt reflector --sort rate -p https --save /etc/pacman.d/mirrorlist -c "United States" -f 5 -l 5
    arch-chroot /mnt rm /etc/localtime
    arch-chroot /mnt ln -s /usr/share/zoneinfo/America/Chicago /etc/localtime
    arch-chroot /mnt hwclock --systohc --utc
    sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /mnt/etc/locale.gen
    arch-chroot /mnt locale-gen
    echo LANG=en_US.UTF-8 > /mnt/etc/locale.conf

    echo "$HOST_NAME" > /mnt/etc/hostname
    sed -i "/::1/a127.0.1.1\t$HOST_NAME.localdomain\t$HOST_NAME" /mnt/etc/hosts
    
    sed -i 's/#Color/Color/' /mnt/etc/pacman.conf
    sed -i "/\[multilib\]/,/Include/"'s/^#//' /mnt/etc/pacman.conf

    arch-chroot /mnt passwd
}

bootloader_bios()
{
    sed -i "s/use_lvmetad = 1/use_lvmetad = 0/" /mnt/etc/lvm/lvm.conf
    arch-chroot /mnt pacman -Syu intel-ucode grub os-prober --noconfirm
    arch-chroot /mnt grub-install --target=i386-pc --recheck "$GRUB"
    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
}

bootloader_uefi()
{
    arch-chroot /mnt pacman -Syu intel-ucode --noconfirm
    arch-chroot /mnt bootctl --path=/boot install
    curl https://raw.githubusercontent.com/jmauss/Arch-Install/master/arch.conf -o /mnt/boot/loader/entries/arch.conf
    sed -i "s/INSERTHERE/$DEVID/" /mnt/boot/loader/entries/arch.conf
    arch-chroot /mnt bootctl update
}

cryptloader_bios()
{
    sed -i 's/base udev autodetect modconf block filesystems/base udev autodetect modconf block encrypt lvm2 filesystems/' /mnt/etc/mkinitcpio.conf
    arch-chroot /mnt mkinitcpio -p linux
    
    sed -i "s/use_lvmetad = 1/use_lvmetad = 0/" /mnt/etc/lvm/lvm.conf
    arch-chroot /mnt pacman -Syu intel-ucode grub os-prober --noconfirm
    arch-chroot /mnt grub-install --target=i386-pc --recheck "$GRUB"
    sed -i "s#GRUB_CMDLINE_LINUX=\"\"#GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=$DEVIDC:luks\"#" /mnt/etc/default/grub
    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
}

cryptloader_uefi()
{
    sed -i 's/base udev autodetect modconf block filesystems/base udev autodetect modconf block encrypt lvm2 filesystems/' /mnt/etc/mkinitcpio.conf
    arch-chroot /mnt mkinitcpio -p linux
    
    arch-chroot /mnt pacman -Syu intel-ucode --noconfirm
    arch-chroot /mnt bootctl --path=/boot install
    curl https://raw.githubusercontent.com/jmauss/Arch-Install/master/cryptarch.conf -o /mnt/boot/loader/entries/arch.conf
    sed -i "s/INSERTHERE/$DEVIDC/" /mnt/boot/loader/entries/arch.conf
    arch-chroot /mnt bootctl update
}

laptop_utilities()
{
    arch-chroot /mnt pacman -S iw wpa_supplicant dialog tlp bluez bluez-utils networkmanager mesa xf86-input-libinput xorg-server --noconfirm
    arch-chroot /mnt systemctl enable tlp.service
    arch-chroot /mnt systemctl enable tlp-sleep.service
    arch-chroot /mnt systemctl disable systemd-rfkill.service
    arch-chroot /mnt systemctl enable bluetooth.service
    
    curl https://raw.githubusercontent.com/jmauss/Arch-Install/master/30-touchpad.conf -o /mnt/etc/X11/xorg.conf.d/30-touchpad.conf
    
    sed -i "s/MODULES=\"\"/MODULES=\"i915\"/" /mnt/etc/mkinitcpio.conf
    arch-chroot /mnt mkinitcpio -p linux
}

desktop_utilities()
{
    arch-chroot /mnt pacman -S nvidia nvidia-libgl networkmanager xf86-input-libinput nvidia-settings --noconfirm
    arch-chroot /mnt systemctl enable NetworkManager.service
}

virtualbox_utilities()
{
    arch-chroot /mnt pacman -S virtualbox-guest-modules-arch networkmanager --noconfirm
    arch-chroot /mnt systemctl enable NetworkManager.service
    while [ 1 ]; do
        read -p "Will you need X support? (y,n): " VMX;
        if [ "$VMX" == 'y' ]; then
            arch-chroot /mnt pacman -S xf86-input-libinput --noconfirm
            arch-chroot /mnt pacman -S virtualbox-guest-utils --noconfirm
            break
        elif [ "$VMX" == 'n' ]; then
            arch-chroot /mnt pacman -S virtualbox-guest-utils-nox --noconfirm
            break
        else
            printf "Invalid input! Please try again\n";
        fi
    done
}

security_tools()
{
    while [ 1 ]; do
        read -p "Will you need security tools? (y,n): " TOOLS;
        if [ "$TOOLS" == 'y' ]; then
            arch-chroot /mnt pacman -S qemu virt-manager ebtables dnsmasq testdisk nmap bind-tools whois openssh postgresql metasploit wireshark-cli john aircrack-ng hashcat hping --noconfirm
            arch-chroot /mnt systemctl enable libvirtd.service
            break
        elif [ "$TOOLS" == 'n' ]; then
            break
        else
            printf "Invalid input! Please try again\n";
        fi
    done
}

printer_drivers()
{
    while [ 1 ]; do
        read -p "Will you need HP Printer drivers? (y,n): " PRNT;
        if [ "$PRNT" == 'y' ]; then
            arch-chroot /mnt pacman -S cups cups-pdf hplip sane --noconfirm
            arch-chroot /mnt systemctl enable org.cups.cupsd.service
            break
        elif [ "$PRNT" == 'n' ]; then
            break
        else
            printf "Invalid input! Please try again\n";
        fi
    done
}

drive_test()
{
    DLET="$(echo "$DISK" | cut -c6-8 )"
    DTEST="$(cat /sys/block/$DLET/queue/rotational)"
    if [ "$DTEST" == '0' ]; then
        printf "Drive is an SSD - enabling TRIM...\n"
        arch-chroot /mnt systemctl enable fstrim.timer
    else
        printf "Drive is an HDD\n";
    fi
}

install_arch()
{
    [ -d "/sys/firmware/efi" ] && MODE="uefi" || MODE="bios"

    while [ 1 ]; do
        read -p "Do you want to encrypt your drive? (y,n): " CRYPT;
        if [ "$CRYPT" == 'y' ]; then
            setup_disk
            grub_"$MODE"
            crypt_swap
            set_hostname
            "$MODE"_cryptpartitioning
            crypt_setup
            system_install
            cryptloader_"$MODE"
            break
        elif [ "$CRYPT" == 'n' ]; then
            setup_disk
            grub_"$MODE"
            set_swap
            set_hostname
            "$MODE"_partitioning
            system_install
            bootloader_"$MODE"
            break
        else
            printf "Invalid input! Please try again\n";
            break;
        fi
    done
}

system_type()
{
    while [ 1 ]; do
        read -p "Is this sytem a Laptop(1), Desktop(2), or VM(3): " STYPE;
        if [ "$STYPE" == '1' ]; then
            laptop_utilities
            security_tools
            printer_drivers
            drive_test
            umount -R /mnt
            sleep 5
            shutdown -r now
        elif [ "$STYPE" == '2' ]; then
            desktop_utilities
            security_tools
            printer_drivers
            drive_test
            umount -R /mnt
            sleep 5
            shutdown -r now
        elif [ "$STYPE" == '3' ]; then
            virtualbox_utilities
            security_tools
            umount -R /mnt
            sleep 5
            shutdown -h now
        else
            printf "Invalid input! Please try again\n";
        fi
    done
}

echo "-----------------------------"
echo "| Arch Linux Install Script |"
echo "-----------------------------"

if ping -c 1 google.com &> /dev/null; then
    echo Connected
    install_arch
    system_type
else
    echo "Not Connected - starting dhcpcd" && dhcpcd && sleep 30s;
fi

install_arch
system_type
