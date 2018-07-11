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
sudo -u $user_name git clone https://aur.archlinux.org/aurman.git
cd aurman/
sudo -u $user_name makepkg -sric --noconfirm --needed --skippgpcheck
cd

sudo -u $user_name aurman -Syu --noedit --noconfirm --needed

# System Core
sudo -u $user_name aurman -S alsa-utils pulseaudio pulseaudio-alsa --noedit --noconfirm --needed # Audio
sudo -u $user_name aurman -S ntfs-3g dosfstools exfat-utils unzip p7zip udevil --noedit --noconfirm --needed # Files/Filesystems
systemctl enable devmon@$user_name.service
sudo -u $user_name aurman -S thermald acpi --noedit --noconfirm --needed # Hardware monitoring
systemctl enable thermald.service

# i3 Core
sudo -u $user_name aurman -S xorg-xinit xautolock xorg-apps --noedit --noconfirm --needed # Xorg utils
sudo -u $user_name aurman -S i3-gaps i3blocks i3lock-fancy-multimonitor-git --noedit --noconfirm --needed # i3 specific
sudo -u $user_name aurman -S feh compton termite rofi --noedit --noconfirm --needed # i3 utils

# System Utilities
sudo -u $user_name aurman -S downgrade htop screenfetch ranger --noedit --noconfirm --needed # Command line
sudo -u $user_name aurman -S mpv --noedit --noconfirm --needed # Graphical

# Themeing
sudo -u $user_name aurman -S qt4 qt5-styleplugins qt5ct lxappearance-gtk3 --noedit --noconfirm --needed # Theme engines
sudo -u $user_name aurman -S ttf-roboto ttf-roboto-mono ttf-liberation noto-fonts noto-fonts-cjk noto-fonts-emoji ttf-font-awesome-4 --noedit --noconfirm --needed # Fonts
sudo -u $user_name aurman -S arc-gtk-theme gnome-themes-extra arc-icon-theme paper-icon-theme-git papirus-icon-theme numix-circle-icon-theme-git --noedit --noconfirm --needed # Themes

sudo sed -i "\$aQT_QPA_PLATFORMTHEME=qt5ct" /etc/environment
sed -i 's/Moka/Paper,Papirus-Dark,Numix-Circle,Moka/' /usr/share/icons/Arc/index.theme

mkdir -p /home/$user_name/Downloads
mkdir -p /home/$user_name/Images
mkdir -p /home/$user_name/Scripts
mkdir -p /home/$user_name/Files
mkdir -p /home/$user_name/.config/termite
mkdir -p /home/$user_name/.config/i3blocks/scripts
mkdir -p /home/$user_name/.config/i3
mkdir -p /home/$user_name/.config/gtk-3.0
mkdir -p /home/$user_name/.config/rofi

curl https://raw.githubusercontent.com/jmauss/Arch-Install/master/i3screens.sh -o /home/$user_name/Scripts/i3screens.sh
curl https://raw.githubusercontent.com/jmauss/Arch-Install/master/.zshrci3 -o /home/$user_name/.zshrc
curl https://raw.githubusercontent.com/jmauss/Arch-Install/master/.xinitrc -o /home/$user_name/.xinitrc
curl https://raw.githubusercontent.com/jmauss/Arch-Install/master/.zprofile -o /home/$user_name/.zprofile 
curl https://raw.githubusercontent.com/jmauss/Arch-Install/master/config/termite/config -o /home/$user_name/.config/termite/config
curl https://raw.githubusercontent.com/jmauss/Arch-Install/master/config/rofi/config -o /home/$user_name/.config/rofi/config
curl https://raw.githubusercontent.com/jmauss/Arch-Install/master/config/gtk-3.0/gtk.css -o /home/$user_name/.config/gtk-3.0/gtk.css
curl https://raw.githubusercontent.com/jmauss/Arch-Install/master/config/i3blocks/i3blocks.conf -o /home/$user_name/.config/i3blocks/i3blocks.conf
curl https://raw.githubusercontent.com/jmauss/Arch-Install/master/config/i3/config -o /home/$user_name/.config/i3/config
cd /home/$user_name/
chown -R $user_name:wheel .zshrc .xinitrc .zprofile .config Downloads Images Scripts Files
chmod u+x Scripts/i3screens.sh
cd

sudo -u $user_name aurman -Rns $(sudo -u $user_name aurman -Qqdt) --noconfirm
sudo -u $user_name aurman -Sc --noconfirm

rm /home/$user_name/.bash*
rm -r 

shutdown -h now
