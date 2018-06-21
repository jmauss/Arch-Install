#!/bin/bash

ask_for_username()
{
    while [ 1 ]; do
        read -p "Enter your name: " name;
        read -p "Enter your username: " user_name;
        if [ $user_name ]; then
            break;
        fi
    done
}

ask_for_password()
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
    echo "Not Connected" && dhcpcd && sleep 2m;
fi

ask_for_username
ask_for_password

echo vm.swappiness=10 > /etc/sysctl.d/99-sysctl.conf
pacman -Syu zsh zsh-completions --noconfirm --needed

useradd -c $name -m -g wheel -s /bin/zsh $user_name

passwd $user_name << EOPF
$passwd1
$passwd2
EOPF

sed -i 's/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers

pacman -Syu git --noconfirm --needed
cd /tmp

sudo -u $user_name git clone https://aur.archlinux.org/pikaur.git
cd pikaur/
sudo -u $user_name makepkg -sric --noconfirm --needed
cd

sudo -u $user_name pikaur -Syu --noedit --noconfirm --needed

sudo -u $user_name pikaur -S xorg-xinit xautolock alsa-utils pulseaudio pulseaudio-alsa --noedit --noconfirm --needed
#sudo -u $user_name pikaur -S udevil mpv qt4 feh compton htop screenfetch ranger lxappearance xdg-user-dirs --noedit --noconfirm --needed
sudo -u $user_name pikaur -S ntfs-3g dosfstools exfat-utils unzip p7zip xorg-apps i3-gaps i3blocks i3lock-fancy-git --noedit --noconfirm --needed
sudo -u $user_name pikaur -S ttf-roboto ttf-roboto-mono ttf-liberation noto-fonts noto-fonts-cjk noto-fonts-emoji ttf-font-awesome gnome-themes-extra paper-icon-theme-git papirus-icon-theme-git numix-circle-icon-theme-git --noedit --noconfirm --needed
sudo -u $user_name pikaur -S thermald termite rofi qt5-styleplugins qt5ct --noedit --noconfirm --needed

# For laptop installation (battery,)
sudo -u $user_name pikaur -S acpi --noedit --noconfirm --needed

# System Utilities
sudo -u $user_name pikaur -S downgrade --noedit --noconfirm --needed

sudo sed -i "\$aQT_QPA_PLATFORMTHEME=qt5ct" /etc/environment
sed -i 's/Adwaita/Papirus-Dark,Numix-Circle,Adwaita/' /usr/share/icons/Paper/index.theme
#systemctl enable devmon@$user_name.service
systemctl enable thermald.service

mkdir -p /home/$user_name/Scripts
mkdir -p /home/$user_name/.config/termite
mkdir -p /home/$user_name/.config/i3blocks/scripts
mkdir -p /home/$user_name/.config/i3
mkdir -p /home/$user_name/.config/gtk-3.0

curl https://raw.githubusercontent.com/jmauss/Arch-Install/master/i3user.sh -o /home/$user_name/Scripts/i3user.sh
curl https://raw.githubusercontent.com/jmauss/Arch-Install/master/Extra/Chrome/i3dark.crx -o /home/$user_name/i3dark.crx
curl https://raw.githubusercontent.com/jmauss/Arch-Install/master/.zshrci3 -o /home/$user_name/.zshrc
curl https://raw.githubusercontent.com/jmauss/Arch-Install/master/.Xresources -o /home/$user_name/.Xresources
curl https://raw.githubusercontent.com/jmauss/Arch-Install/master/.xinitrc -o /home/$user_name/.xinitrc
curl https://raw.githubusercontent.com/jmauss/Arch-Install/master/.zprofile -o /home/$user_name/.zprofile 
curl https://raw.githubusercontent.com/jmauss/Arch-Install/master/config/termite/config -o /home/$user_name/.config/termite/config
curl https://raw.githubusercontent.com/jmauss/Arch-Install/master/config/gtk-3.0/gtk.css -o /home/$user_name/.config/gtk-3.0/gtk.css
curl https://raw.githubusercontent.com/jmauss/Arch-Install/master/config/i3blocks/i3blocks.conf -o /home/$user_name/.config/i3blocks/i3blocks.conf
curl https://raw.githubusercontent.com/jmauss/Arch-Install/master/config/i3/config -o /home/$user_name/.config/i3/config
cd /home/$user_name/
chown -R $user_name:wheel i3dark.crx .zshrc .Xresources .xinitrc .zprofile .config Scripts
chmod u+x Scripts/i3user.sh
cd

sudo -u $user_name pikaur -Rns $(pikaur -Qqdt) --noconfirm
sudo -u $user_name pikaur -Sc --noconfirm

rm /home/$user_name/.bash*
rm -r 

shutdown -r now
