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

sudo -u $user_name git clone https://aur.archlinux.org/yay.git
cd yay/
sudo -u $user_name makepkg -sric --noconfirm --needed
cd

sudo -u $user_name yay -Syu --noconfirm --needed

# System Core
sudo -u $user_name yay -S downgrade ntfs-3g dosfstools exfat-utils unzip p7zip unrar thermald cups cups-pdf --noconfirm --needed

# Audio Drivers
sudo -u $user_name yay -S alsa-utils pulseaudio pulseaudio-alsa --noconfirm --needed

# Budgie Core
sudo -u $user_name yay -S otf-san-francisco otf-sfmono ttf-liberation noto-fonts noto-fonts-cjk noto-fonts-emoji --noconfirm --needed

sudo -u $user_name yay -S budgie-desktop dconf-editor lightdm-settings alacarte eog file-roller network-manager-applet nautilus gnome-{calculator,calendar,disk-utility,font-viewer,keyring,mpv,screenshot,screensaver,system-log,system-monitor,terminal} xdg-user-dirs-gtk gedit system-config-printer --noconfirm --needed

# System Theming 
sudo -u $user_name yay -S mojave-gtk-theme-git papirus-icon-theme lib32-fontconfig qt4 qt5-styleplugins qt5ct --noconfirm --needed

sed -i "\$aQT_QPA_PLATFORMTHEME=qt5ct" /etc/environment
sed -i 's/#greeter-session=example-gtk-gnome/greeter-session=lightdm-slick-greeter/' /etc/lightdm/lightdm.conf
systemctl enable thermald.service
systemctl enable lightdm.service
systemctl enable org.cups.cupsd.service

curl https://raw.githubusercontent.com/jmauss/Arch-Install/master/.zshrc -o /home/$user_name/.zshrc
curl https://raw.githubusercontent.com/jmauss/Arch-Install/master/termcolors.sh -o /home/$user_name/termcolors.sh
chown $user_name:wheel /home/$user_name/.zshrc /home/$user_name/termcolors.sh

sudo -u $user_name yay -Yc --noconfirm
sudo -u $user_name yay -Sc --noconfirm

rm /home/$user_name/.bash*
rm -r *

shutdown -h now
