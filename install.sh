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
    printf "Swap size (eg. 2G): "

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
            read -p "Swap size (in GB): " SWAP;
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
    DEVIDB=$(blkid -s UUID -o value "${DISK}2")

    pacstrap /mnt base base-devel

    genfstab -pU /mnt >> /mnt/etc/fstab

    arch-chroot /mnt pacman -S reflector --noconfirm
    arch-chroot /mnt reflector --sort rate -p https --save /etc/pacman.d/mirrorlist -c "United States" -f 5 -l 5
    arch-chroot /mnt ln -s /usr/share/zoneinfo/America/Chicago /etc/localtime
    arch-chroot /mnt hwclock --systohc --utc
    sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /mnt/etc/locale.gen
    arch-chroot /mnt locale-gen
    echo LANG=en_US.UTF-8 > /mnt/etc/locale.conf

    echo "$HOST_NAME" > /mnt/etc/hostname
    sed -i "/^127.0.0.1/ s/$/\t$HOST_NAME/" /mnt/etc/hosts
    sed -i "/^::1/ s/$/\t$HOST_NAME/" /mnt/etc/hosts

    sed -i "s/use_lvmetad = 1/use_lvmetad = 0/" /mnt/etc/lvm/lvm.conf

    sed -i 's/HOOKS="base udev autodetect modconf block filesystems/HOOKS="base udev autodetect modconf block encrypt lvm2 filesystems/' /mnt/etc/mkinitcpio.conf
    arch-chroot /mnt mkinitcpio -p linux

    arch-chroot /mnt passwd
}

bootloader_bios()
{
    arch-chroot /mnt pacman -S intel-ucode grub os-prober --noconfirm
    arch-chroot /mnt grub-install --target=i386-pc --recheck "$GRUB"
    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
}

bootloader_uefi()
{
    arch-chroot /mnt pacman -S intel-ucode --noconfirm
    arch-chroot /mnt bootctl --path=/boot install
    curl https://raw.githubusercontent.com/jmauss/Arch-Install/master/arch.conf -o /mnt/boot/loader/entries/arch.conf
    sed -i "s/INSERTHERE/$DEVID/" /mnt/boot/loader/entries/arch.conf
    arch-chroot /mnt bootctl update
}

cryptloader_bios()
{
    arch-chroot /mnt pacman -S intel-ucode grub os-prober --noconfirm
    arch-chroot /mnt grub-install --target=i386-pc --recheck "$GRUB"
    sed -i "s#GRUB_CMDLINE_LINUX=\"\"#GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=$DEVIDB:lvm\"#" /mnt/etc/default/grub
    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
}

cryptloader_uefi()
{
    arch-chroot /mnt pacman -S intel-ucode --noconfirm
    arch-chroot /mnt bootctl --path=/boot install
    curl https://raw.githubusercontent.com/jmauss/Arch-Install/master/cryptarch.conf -o /mnt/boot/loader/entries/arch.conf
    sed -i "s/INSERTHERE/$DEVID/" /mnt/boot/loader/entries/arch.conf
    arch-chroot /mnt bootctl update
}

laptop_utilities()
{
    arch-chroot /mnt pacman -S iw wpa_supplicant dialog --noconfirm
}

desktop_utilities()
{
    arch-chroot /mnt pacman -S nvidia nvidia-libgl xf86-input-libinput --noconfirm
}

virtualbox_utilities()
{
    arch-chroot /mnt pacman -S virtualbox-guest-modules-arch --noconfirm
    while [ 1 ]; do
            read -p "Will you need X support? (y,n): " VMX;
            if [ "$VMX" == 'y' ]; then
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
                    umount -R /mnt
                    shutdown -r now
            elif [ "$STYPE" == '2' ]; then
                    desktop_utilities
                    umount -R /mnt
                    shutdown -r now
            elif [ "$STYPE" == '3' ]; then
                    virtualbox_utilities
                    umount -R /mnt
                    shutdown -h now
            else
                printf "Invalid input! Please try again\n";
            fi
    done
}

echo "-----------------------------"
echo "- Arch Linux Install Script -"
echo "-----------------------------"

if ping -c 1 google.com &> /dev/null; then
  echo Connected
  install_arch
  system_type
else
  echo "Not Connected" && dhcpcd && sleep 30s
fi

install_arch
system_type
