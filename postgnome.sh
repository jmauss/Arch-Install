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

# Audio Drivers
sudo -u $user_name pacaur -S alsa-utils pulseaudio pulseaudio-alsa lib32-libpulse lib32-alsa-plugins --noconfirm --noedit

# System Core
sudo -u $user_name pacaur -S downgrade qt4 ntfs-3g dosfstools unzip p7zip ebtables dnsmasq ttf-roboto ttf-roboto-mono ttf-liberation lib32-fontconfig thermald qt5-styleplugins qt5ct xorg-xprop xorg-xwininfo  --noconfirm --noedit

# Gnome Core
sudo -u $user_name pacaur -S adwaita-icon-theme baobab dconf-editor eog gdm gnome-{backgrounds,calculator,control-center,disk-utility,font-viewer,keyring,screensaver,screenshot,settings-daemon,system-log,system-monitor,terminal,tweak-tool,user-share} grilo-plugins gtk3-print-backends gucharmap gvfs gvfs-{afc,goa,google,gphoto2,mtp,nfs,smb} mousetweaks nautilus sushi tracker vino xdg-user-dirs-gtk gedit networkmanager network-manager-applet gnome-boxes --noconfirm --noedit

# Shell Extensions
sudo -u $user_name pacaur -S gnome-shell-extension-{activities-config,topicons-plus-git,dash-to-dock-git,weather-git} --noconfirm --noedit

# System Programs
sudo -u $user_name pacaur -S vlc chromium pepper-flash chromium-widevine --noconfirm --noedit

# System Theming 
sudo -u $user_name pacaur -S paper-icon-theme-git numix-circle-icon-theme-git --noconfirm --noedit

sudo sed -i "\$aQT_QPA_PLATFORMTHEME=qt5ct" /etc/environment
sed -i 's/Adwaita/Numix-Circle,Adwaita/' /usr/share/icons/Paper/index.theme
curl https://raw.githubusercontent.com/jmauss/Arch-Install/master/mirrorupgrade.hook -o /etc/pacman.d/mirrorupgrade.hook
systemctl enable thermald.service
systemctl enable gdm.service
systemctl enable NetworkManager.service
systemctl enable libvirtd.service

mkdir -p /home/$user_name/Builds
mkdir -p /home/$user_name/.config/cower
cd /home/$user_name/
curl -O https://raw.githubusercontent.com/jmauss/Arch-Install/master/.zshrc
curl -O https://raw.githubusercontent.com/jmauss/Arch-Install/master/extractGSTcss.sh
curl -O https://raw.githubusercontent.com/jmauss/Arch-Install/master/Extra/Chrome/gnomedark.crx
cp /usr/share/doc/cower/config .config/cower/
sed -i 's/#TargetDir =/TargetDir = ~\/Builds\//' .config/cower/config
chown -R $user_name:wheel gnomedark.crx extractGSTcss.sh .zshrc .config Builds
cd

usermod -a -G libvirt $user_name
pacman -Rns pacaur --noconfirm

rm /home/$user_name/.bash*
rm -r /home/$user_name/.cache/pacaur/
rm -r *

shutdown -r now
