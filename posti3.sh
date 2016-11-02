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

sudo -u $user_name pacaur -S xf86-video-intel mesa-libgl lib32-mesa-libgl xf86-input-libinput xorg-server xorg-xinit alsa-utils pulseaudio pulseaudio-alsa --noconfirm --noedit
# Audio support for 32-bit software sudo -u $user_name pacaur -S lib32-libpulse lib32-alsa-plugins 
sudo -u $user_name pacaur -S mpv qt4 shutter feh compton htop screenfetch ranger networkmanager lxappearance xdg-user-dirs ntfs-3g dosfstools unzip p7zip xorg-utils i3-gaps i3blocks i3lock-fancy-git --noconfirm --noedit
sudo -u $user_name pacaur -S ttf-roboto ttf-roboto-mono ttf-liberation ttf-font-awesome gtk-theme-arc-grey-git paper-icon-theme-git numix-circle-icon-theme-git --noconfirm --noedit
sudo -u $user_name pacaur -S thermald termite rofi qt5-styleplugins qt5ct --noconfirm --noedit
sudo sed -i "\$aQT_QPA_PLATFORMTHEME=qt5ct" /etc/environment
sed -i 's/Adwaita/Numix-Circle,Adwaita/' /usr/share/icons/Paper/index.theme
xdg-user-dirs-update
curl https://raw.githubusercontent.com/jmauss/Arch-Install/master/mirrorupgrade.hook -o /etc/pacman.d/mirrorupgrade.hook
systemctl enable thermald.service
systemctl enable NetworkManager.service

mkdir -p /home/$user_name/.config/termite
mkdir -p /home/$user_name/.config/i3blocks/scripts
mkdir -p /home/$user_name/.config/i3
mkdir -p /home/$user_name/.config/gtk-3.0
curl https://raw.githubusercontent.com/jmauss/Arch-Install/master/.zshrci3 -o /home/$user_name/.zshrc
curl https://raw.githubusercontent.com/jmauss/Arch-Install/master/.Xresources -o /home/$user_name/.Xresources
curl https://raw.githubusercontent.com/jmauss/Arch-Install/master/.xinitrc -o /home/$user_name/.xinitrc
curl https://raw.githubusercontent.com/jmauss/Arch-Install/master/.zprofile -o /home/$user_name/.zprofile 
curl https://raw.githubusercontent.com/jmauss/Arch-Install/master/config/termite/config -o /home/$user_name/.config/termite/config
curl https://raw.githubusercontent.com/jmauss/Arch-Install/master/config/gtk-3.0/gtk.css -o /home/$user_name/.config/gtk-3.0/gtk.css
curl https://raw.githubusercontent.com/jmauss/Arch-Install/master/config/i3blocks/i3blocks.conf -o /home/$user_name/.config/i3blocks/i3blocks.conf
curl https://raw.githubusercontent.com/jmauss/Arch-Install/master/config/i3blocks/scripts/playing.py -o /home/$user_name/.config/i3blocks/scripts/playing.py
curl https://raw.githubusercontent.com/jmauss/Arch-Install/master/config/i3/config -o /home/$user_name/.config/i3/config
cd /home/$user_name/
chown -R $user_name:wheel .zshrc .Xresources .xinitrc .zprofile .config
cd

rm /home/$user_name/.bash*
rm -r *
rm .bash_history

shutdown -r now
