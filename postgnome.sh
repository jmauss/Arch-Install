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

user_add()
{
    while [ 1 ]; do
        if pacman -Qs gnome-boxes > /dev/null ; then
            read -p "Will this user need access to Gnome Boxes? (y,n): " GUSR;
            if [ "$GUSR" == 'y' ]; then
                pacman -S gnome-boxes --noconfirm --needed
                pacman -Rns virt-manager --noconfirm
                useradd -c $name -m -g wheel -G libvirt -s /bin/zsh $user_name
                break
            elif [ "$GUSR" == 'n' ]; then
                useradd -c $name -m -g wheel -s /bin/zsh $user_name
                break
            else
                printf "Invalid input! Please try again\n";
            fi
        else
            useradd -c $name -m -g wheel -s /bin/zsh $user_name
            break
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
pacman -Syu zsh zsh-completions --noconfirm

user_add

passwd $user_name << EOPF
$passwd1
$passwd2
EOPF

sed -i 's/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf

pacman -Syu git --noconfirm --needed
cd /tmp

sudo -u $user_name git clone https://aur.archlinux.org/cower.git
cd cower/
sudo -u $user_name makepkg -sric --noconfirm --skippgpcheck
cd /tmp

sudo -u $user_name git clone https://aur.archlinux.org/pacaur.git
cd pacaur/
sudo -u $user_name makepkg -sric --noconfirm
cd

sudo -u $user_name pacaur -Syu --noedit --noconfirm

# Audio Drivers
sudo -u $user_name pacaur -S alsa-utils pulseaudio pulseaudio-alsa --noconfirm --noedit --needed

# System Core
sudo -u $user_name pacaur -S downgrade qt4 ntfs-3g dosfstools unzip p7zip ebtables dnsmasq ttf-roboto ttf-roboto-mono ttf-liberation noto-fonts noto-fonts-cjk noto-fonts-emoji lib32-fontconfig thermald qt5-styleplugins qt5ct xorg-xprop xorg-xwininfo  --noconfirm --noedit --needed

# Gnome Core
sudo -u $user_name pacaur -S adwaita-icon-theme baobab dconf-editor eog gdm gnome-{backgrounds,calculator,control-center,disk-utility,shell-extensions,font-viewer,keyring,screensaver,screenshot,settings-daemon,system-log,system-monitor,terminal,tweak-tool,user-share} grilo-plugins gtk3-print-backends gucharmap gvfs gvfs-{afc,goa,google,gphoto2,mtp,nfs,smb} mousetweaks nautilus sushi tracker vino xdg-user-dirs-gtk gedit network-manager-applet --noconfirm --noedit --needed

# Shell Extensions
sudo -u $user_name pacaur -S gnome-shell-extension-{activities-config,topicons-plus-git,dash-to-dock-git,weather-git} --noconfirm --noedit --needed

# System Programs
sudo -u $user_name pacaur -S vlc --noconfirm --noedit --needed

# System Theming 
sudo -u $user_name pacaur -S papirus-icon-theme-git numix-circle-icon-theme-git folder-color-nautilus-bzr hardcode-tray sni-qt-patched-git --noconfirm --noedit --needed # paper-icon-theme-git lib32-sni-qt-patched-git

sudo sed -i "\$aQT_QPA_PLATFORMTHEME=qt5ct" /etc/environment
#sed -i 's/Adwaita/Numix-Circle,Adwaita/' /usr/share/icons/Paper/index.theme
sed -i 's/breeze-dark/Numix-Circle,breeze-dark/' /usr/share/icons/Papirus-Dark/index.theme
systemctl enable thermald.service
systemctl enable gdm.service

cd /home/$user_name/
curl -O https://raw.githubusercontent.com/jmauss/Arch-Install/master/.zshrc
curl -O https://raw.githubusercontent.com/jmauss/Arch-Install/master/extractGSTcss.sh
curl -O https://raw.githubusercontent.com/jmauss/Arch-Install/master/Extra/Chrome/gnomedark.crx
chown -R $user_name:wheel gnomedark.crx extractGSTcss.sh .zshrc
chmod u+x extractGSTcss.sh
cd

pacman -Rns $(pacman -Qqdt) --noconfirm

rm /home/$user_name/.bash*
rm -r /home/$user_name/.cache/pacaur/
rm -r *

shutdown -r now
