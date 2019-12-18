#!/usr/bin/env sh

# This is a script to partition disks and install encrypted Arch Linux with UEFI

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

choose_disk()
{
    echo "Available disks:"
    lsblk -dn -e 2,7,11 -p -o NAME,SIZE | column
    prompt "Installation drive: " DISK "$(lsblk -dn -e 2,7,11 -p -o NAME)"

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

partition_disk()
{
    timedatectl set-ntp true

    parted -s --align optimal -- "$DISK" mklabel gpt \
        mkpart ESP fat32 1MiB 513MiB \
        set 1 boot on \
        mkpart primary ext4 513MiB 100%

    mkfs.vfat -F32 "${DISK}p1"
}

system_setup()
{
    cryptsetup --verbose --cipher aes-xts-plain64 --key-size 512 --hash sha512 --iter-time 5000 --use-random --batch-mode luksFormat "${DISK}p2"
    cryptsetup luksOpen "${DISK}p2" luks 

    pvcreate /dev/mapper/luks
    vgcreate arch /dev/mapper/luks
    lvcreate -l +100%FREE -n root arch

    mkfs.ext4 /dev/mapper/arch-root

    mount /dev/mapper/arch-root /mnt
    mkdir /mnt/boot
    mount "${DISK}p1" /mnt/boot
}

system_install()
{
    pacstrap /mnt base linux linux-firmware lvm2 man-db man-pages texinfo vi

    genfstab -U /mnt >> /mnt/etc/fstab

    arch-chroot /mnt pacman -Syu reflector iw wpa_supplicant dialog tlp --noconfirm --needed
    arch-chroot /mnt systemctl enable tlp.service
    arch-chroot /mnt systemctl enable tlp-sleep.service
    arch-chroot /mnt systemctl disable systemd-rfkill.service
    arch-chroot /mnt reflector --sort rate --save /etc/pacman.d/mirrorlist -c "United States" -f 5 -l 5
    arch-chroot /mnt ln -sf /usr/share/zoneinfo/America/Chicago /etc/localtime
    arch-chroot /mnt hwclock --systohc --utc
    sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /mnt/etc/locale.gen
    arch-chroot /mnt locale-gen
    echo LANG=en_US.UTF-8 > /mnt/etc/locale.conf

    echo "$HOST_NAME" > /mnt/etc/hostname
    sed -i "\$a127.0.0.1\tlocalhost\n::1\t\tlocalhost\n127.0.1.1\t$HOST_NAME.localdomain\t$HOST_NAME" /mnt/etc/hosts
    
    sed -i 's/#Color/Color/' /mnt/etc/pacman.conf
    sed -i "/\[multilib\]/,/Include/"'s/^#//' /mnt/etc/pacman.conf

    echo "Please enter a password for root..."
    arch-chroot /mnt passwd
}

bootloader()
{
    DEVID=$(blkid -s UUID -o value "${DISK}p2")

    sed -i 's/base udev autodetect modconf block filesystems/base udev autodetect modconf block encrypt lvm2 filesystems/' /mnt/etc/mkinitcpio.conf
    sed -i 's/MODULES=()/MODULES=(i915)/' /mnt/etc/mkinitcpio.conf
    arch-chroot /mnt mkinitcpio -p linux
    
    arch-chroot /mnt pacman -S intel-ucode --noconfirm --needed
    arch-chroot /mnt bootctl --path=/boot install
    curl https://raw.githubusercontent.com/jmauss/Arch-Install/master/cryptarch.conf -o /mnt/boot/loader/entries/arch.conf
    sed -i "s/INSERTHERE/$DEVID/" /mnt/boot/loader/entries/arch.conf
    arch-chroot /mnt bootctl update
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

echo "-----------------------------"
echo "| Arch Linux Install Script |"
echo "-----------------------------"

choose_disk
set_hostname
partition_disk
system_setup
system_install
bootloader
drive_test
umount -R /mnt
sleep 5
poweroff