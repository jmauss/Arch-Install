#!/bin/bash

ask_for_username()
{
    while [ 1 ]; do
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
pacman -Syu zsh zsh-completions git --noconfirm --needed

useradd -m -g wheel -s /bin/zsh $user_name

passwd $user_name << EOPF
$passwd1
$passwd2
EOPF

sed -i 's/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers

cd /tmp
sudo -u $user_name git clone https://aur.archlinux.org/yay.git
cd yay/
sudo -u $user_name makepkg -sric --noconfirm --needed
cd

sudo -u $user_name yay -Syu --noedit --noconfirm --needed
sudo -u $user_name yay --editmenu --nodiffmenu --save

# System Core
sudo -u $user_name yay -S alsa-utils pulseaudio pulseaudio-alsa --noconfirm --needed # Audio
sudo -u $user_name yay -S ntfs-3g dosfstools exfat-utils unzip p7zip unrar udevil --noconfirm --needed # Files/Filesystems
systemctl enable devmon@$user_name.service
sudo -u $user_name yay -S thermald acpi --noconfirm --needed # Hardware monitoring
systemctl enable thermald.service

# i3 Core
sudo -u $user_name yay -S xorg-xinit xautolock xorg-apps --noconfirm --needed # Xorg utils
sudo -u $user_name yay -S i3-gaps i3blocks i3lock-fancy-multimonitor-git --noconfirm --needed # i3 specific
sudo -u $user_name yay -S feh compton termite rofi --noconfirm --needed # i3 utils

# System Utilities
sudo -u $user_name yay -S downgrade htop screenfetch ranger -noconfirm --needed # Command line
sudo -u $user_name yay -S mpv --noconfirm --needed # Graphical

# Themeing
sudo -u $user_name yay -S qt4 qt5-styleplugins qt5ct lxappearance-gtk3 --noconfirm --needed # Theme engines
sudo -u $user_name yay -S ttf-roboto nerd-fonts-roboto-mono ttf-liberation noto-fonts noto-fonts-cjk noto-fonts-emoji ttf-font-awesome-4 --noconfirm --needed # Fonts
sudo -u $user_name yay -S vimix-gtk-themes-git papirus-icon-theme --noconfirm --needed # Themes

cd /tmp
sudo -u $user_name git clone https://github.com/alexanderjeurissen/ranger_devicons
cd ranger_devicons/
sudo -u $user_name make install
cd

sudo sed -i "\$aQT_QPA_PLATFORMTHEME=qt5ct" /etc/environment

mkdir -p /home/$user_name/Downloads
mkdir -p /home/$user_name/Images
mkdir -p /home/$user_name/Scripts
mkdir -p /home/$user_name/Files
mkdir -p /home/$user_name/.config/termite
mkdir -p /home/$user_name/.config/i3blocks/scripts
mkdir -p /home/$user_name/.config/i3
mkdir -p /home/$user_name/.config/gtk-3.0
mkdir -p /home/$user_name/.config/rofi

curl https://raw.githubusercontent.com/jmauss/Arch-Install/master/Extra/Chrome/i3dark.crx -o /home/$user_name/i3dark.crx
curl https://raw.githubusercontent.com/jmauss/Arch-Install/master/.zshrci3 -o /home/$user_name/.zshrc
curl https://raw.githubusercontent.com/jmauss/Arch-Install/master/.xinitrc -o /home/$user_name/.xinitrc
curl https://raw.githubusercontent.com/jmauss/Arch-Install/master/.zprofile -o /home/$user_name/.zprofile 
curl https://raw.githubusercontent.com/jmauss/Arch-Install/master/config/termite/config -o /home/$user_name/.config/termite/config
curl https://raw.githubusercontent.com/jmauss/Arch-Install/master/config/rofi/config -o /home/$user_name/.config/rofi/config
curl https://raw.githubusercontent.com/jmauss/Arch-Install/master/config/gtk-3.0/gtk.css -o /home/$user_name/.config/gtk-3.0/gtk.css
curl https://raw.githubusercontent.com/jmauss/Arch-Install/master/config/i3blocks/i3blocks.conf -o /home/$user_name/.config/i3blocks/i3blocks.conf
curl https://raw.githubusercontent.com/jmauss/Arch-Install/master/config/i3/config -o /home/$user_name/.config/i3/config
cd /home/$user_name/
chown -R $user_name:wheel i3dark.crx .zshrc .xinitrc .zprofile .config Downloads Images Scripts Files
cd

sudo -u $user_name yay -Yc --noconfirm
sudo -u $user_name yay -Sc --noconfirm

rm /home/$user_name/.bash*
rm -r 

shutdown -h now
