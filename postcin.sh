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

# System Core
sudo -u $user_name pikaur -S downgrade ntfs-3g dosfstools unzip p7zip thermald --noconfirm --noedit --needed

# Audio Drivers
sudo -u $user_name pikaur -S alsa-utils pulseaudio pulseaudio-alsa --noconfirm --noedit --needed

# Cinnamon Core
sudo -u $user_name pikaur -S ttf-roboto ttf-roboto-mono ttf-liberation noto-fonts noto-fonts-cjk noto-fonts-emoji --noconfirm --noedit --needed

sudo -u $user_name pikaur -S cinnamon lightdm-settings eog gnome-{calculator,disk-utility,font-viewer,keyring,screenshot,system-log,system-monitor,terminal} xdg-user-dirs-gtk gedit blueberry system-config-printer --noconfirm --noedit --needed

# System Programs
#sudo -u $user_name pikaur -S  --noconfirm --noedit --needed

# System Theming 
sudo -u $user_name pikaur -S paper-icon-theme-git papirus-icon-theme-git numix-circle-icon-theme-git lib32-fontconfig qt4 qt5-styleplugins qt5ct --noconfirm --noedit --needed

sed -i "\$aQT_QPA_PLATFORMTHEME=qt5ct" /etc/environment
sed -i 's/Adwaita/Papirus-Dark,Numix-Circle,Adwaita/' /usr/share/icons/Paper/index.theme
sed -i 's/#greeter-session=example-gtk-gnome/greeter-session=slick-greeter/' /etc/lightdm/lightdm.conf
systemctl enable thermald.service
systemctl enable lightdm.service

curl https://raw.githubusercontent.com/jmauss/Arch-Install/master/.zshrc -o /home/jmauss/.zshrc
chown $user_name:wheel /home/jmauss/.zshrc

sudo -u $user_name pikaur -Rns $(pikaur -Qqdt) --noconfirm
sudo -u $user_name pikaur -Sc --noconfirm

rm /home/$user_name/.bash*
rm -r *

shutdown -h now
