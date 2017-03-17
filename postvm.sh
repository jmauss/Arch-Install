#!/bin/bash

function ask_for_username()
{
    while [ 1 ]; do
        read -p "Enter your name: " name;
        read -p "Enter your username: " user_name;
        if [ $user_name ]; then
            break;
        fi
    done
}

function ask_for_password()
{
    while [ 1 ]; do
        stty -echo
        read -p "Preferred password: " passwd1; echo
        read -p "Enter the password again: " passwd2; echo
        stty echo
        if [ "$passwd1" == "$passwd2" ]; then
            break;
        else
            echo "Passwords do not match. Please try again.";
        fi
    done
}

if ping -c 1 google.com &> /dev/null; then
    echo Connected
else
    echo "Not Connected" && dhcpcd && sleep 2m
fi

ask_for_username
ask_for_password

echo vm.swappiness=10 > /etc/sysctl.d/99-sysctl.conf
pacman -Syu zsh zsh-completions --noconfirm

useradd -c $name -m -g wheel -s /bin/zsh $user_name
passwd $user_name << EOPF
$passwd1
$passwd2
EOPF

sed -i 's/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf

sudo -u $user_name sudo pacman -Syu htop screenfetch ranger ntfs-3g dosfstools dos2unix unzip p7zip git --noconfirm
curl -k "https://www.archlinux.org/mirrorlist/?country=US&protocol=http&ip_version=4&use_mirror_status=on" -o /etc/pacman.d/mirrorlist
sed -i 's/#Server/Server/' /etc/pacman.d/mirrorlist
curl -k https://raw.githubusercontent.com/jmauss/Arch-Install/master/.zshrc -o /home/$user_name/.zshrc
chown -R $user_name:wheel .zshrc
rm /home/$user_name/.bash*
rm -r *

sudo -u $user_name sudo pacman -Rns reflector --noconfirm
sudo -u $user_name sudo pacman -Rns $(pacman -Qqdt) --noconfirm

shutdown -r now
