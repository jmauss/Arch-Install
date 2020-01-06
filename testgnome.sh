#!/usr/bin/env bash

# Get real name and handle for user
getUsername()
{
    while [ 1 ]; do
        read -p "Enter your name: " name;
        read -p "Enter your username: " user_name;
        if [ $user_name ]; then
            break;
        fi
    done
}

# Install zsh, completions, and git (for yay)
pacman -Syu zsh zsh-completions git --noconfirm

# Add user as a member of the group wheel with zsh as the default shell
getUsername
useradd -c $name -m -g wheel -s /bin/zsh $user_name
passwd $user_name

# Allow members of the group 'wheel' sudo access
sed -i 's/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers

# Build yay
cd /tmp
sudo -u $user_name git clone https://aur.archlinux.org/yay.git
cd yay/
sudo -u $user_name makepkg -sric --noconfirm
cd 

# Setup and sync yay
sudo -u $user_name yay --editmenu --nodiffmenu --combinedupgrade --nocleanmenu --save
sudo -u $user_name yay -Syu --noconfirm --needed

# Gnome Core
sudo -u $user_name yay -S file-roller gdm gnome-{backgrounds,control-center,keyring,session,settings-daemon,shell,shell-extensions,themes-extra,grilo-plugins} mousetweaks mutter nautilus networkmanager sushi xdg-user-dirs-gtk --noconfirm --needed # Desktop environment
sudo -u $user_name yay -S gnome-shell-extension-{activities-config,dash-to-dock,remove-dropdown-arrows-git,topicons-plus-git,weather-git} --noconfirm --needed # Shell extensions
sudo -u $user_name yay -S fonts-roboto-ttf liberation-fonts-ttf noto-fonts-ttf noto-fonts-cjk noto-fonts-emoji --noconfirm --needed # Fonts
sudo -u $user_name yay -S papirus-icon-theme --noconfirm --needed # Theming

# Utils
sudo -u $user_name yay -S baobab dconf-editor eog evince gedit gnome-{calculator,calendar,disk-utility,font-viewer,logs,maps,screenshot,system-monitor,terminal,tweaks} totem --noconfirm --needed # Gnome
sudo -u $user_name yay -S virtualbox virtualbox-host-modules-arch virtualbox-ext-oracle papirus-icon-theme --noconfirm --needed # Virtualization
sudo -u $user_name yay -S ntfs-3g dosfstools exfat-utils unzip p7zip unrar --noconfirm --needed # Files/Filesystems
sudo -u $user_name yay -S downgrade neofetch --noconfirm --needed # Command Line

# Services
systemctl enable gdm.service
systemctl enable NetworkManager.service

# Pull config files
curl https://raw.githubusercontent.com/jmauss/Arch-Install/master/.zshrc -o /home/$user_name/.zshrc

# Set up folders
xdg-user-dirs-update

# Cleanup
sudo -u $user_name yay -Yc --noconfirm
sudo -u $user_name yay -Sc --noconfirm

rm /home/$user_name/.bash*
rm -r *
poweroff