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

if ping -c 1 google.com &> /dev/null
then
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

pacman -Syu git --noconfirm
cd /tmp

sudo -u $user_name git clone https://aur.archlinux.org/cower.git
cd cower/
sudo -u $user_name makepkg -sri --noconfirm --skippgpcheck
cd /tmp

sudo -u $user_name git clone https://aur.archlinux.org/pacaur.git
cd pacaur/
sudo -u $user_name makepkg -sri --noconfirm
cd

sudo -u $user_name pacaur -Syu --noedit --noconfirm

sudo -u $user_name pacaur -S xorg-xinit xautolock alsa-utils pulseaudio pulseaudio-alsa --noconfirm --noedit
sudo -u $user_name pacaur -S mpv qt4 shutter feh compton htop screenfetch ranger networkmanager lxappearance xdg-user-dirs ntfs-3g dosfstools unzip p7zip xorg-utils i3-gaps i3blocks i3lock-fancy-git --noconfirm --noedit
sudo -u $user_name pacaur -S ttf-roboto ttf-roboto-mono ttf-liberation ttf-font-awesome gnome-themes-standard paper-icon-theme-git numix-circle-icon-theme-git --noconfirm --noedit
sudo -u $user_name pacaur -S thermald termite rofi qt5-styleplugins qt5ct --noconfirm --noedit

# For laptop installation (battery,)
sudo -u $user_name pacaur -S acpi --noconfirm --noedit

# System Utilities
sudo -u $user_name pacaur -S downgrade --noconfirm --noedit

sudo sed -i "\$aQT_QPA_PLATFORMTHEME=qt5ct" /etc/environment
sed -i 's/Adwaita/Numix-Circle,Adwaita/' /usr/share/icons/Paper/index.theme
curl https://raw.githubusercontent.com/jmauss/Arch-Install/master/mirrorupgrade.hook -o /etc/pacman.d/mirrorupgrade.hook
systemctl enable thermald.service
systemctl enable NetworkManager.service

mkdir -p /home/$user_name/Builds
mkdir -p /home/$user_name/Scripts
mkdir -p /home/$user_name/.config/cower
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
curl https://raw.githubusercontent.com/jmauss/Arch-Install/master/config/i3blocks/scripts/playing -o /home/$user_name/.config/i3blocks/scripts/playing
curl https://raw.githubusercontent.com/jmauss/Arch-Install/master/config/i3blocks/scripts/sp -o /home/$user_name/.config/i3blocks/scripts/sp
curl https://raw.githubusercontent.com/jmauss/Arch-Install/master/config/i3/config -o /home/$user_name/.config/i3/config
cd /home/$user_name/
cp /usr/share/doc/cower/config .config/cower/
sed -i 's/#TargetDir =/TargetDir = ~\/Builds\//' .config/cower/config
chown -R $user_name:wheel i3dark.crx .zshrc .Xresources .xinitrc .zprofile .config Builds
chmod u+x Scripts/i3user.sh
cd .config/i3blocks/scripts/
chmod u+x playing sp
cd

pacman -Rns pacaur --noconfirm

rm /home/$user_name/.bash*
rm -r /home/$user_name/.cache/pacaur/
rm -r *

shutdown -r now
