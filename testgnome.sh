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
echo "Create an admin account..."
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
sudo -u $user_name yay -S chrome-gnome-shell file-roller gdm gnome-{backgrounds,control-center,keyring,session,settings-daemon,shell,shell-extensions,themes-extra} grilo-plugins mousetweaks mutter nautilus networkmanager sushi xdg-user-dirs-gtk --noconfirm --needed # Desktop environment
sudo -u $user_name yay -S ttf-roboto ttf-roboto-mono ttf-liberation noto-fonts noto-fonts-cjk noto-fonts-emoji --noconfirm --needed # Fonts
sudo -u $user_name yay -S papirus-icon-theme --noconfirm --needed # Theming

# Utils
sudo -u $user_name yay -S baobab dconf-editor eog gedit gnome-{calculator,calendar,disk-utility,font-viewer,logs,maps,screenshot,system-monitor,terminal,tweaks} totem --noconfirm --needed # Gnome
sudo -u $user_name yay -S virtualbox-host-modules-arch virtualbox virtualbox-ext-oracle --noconfirm --needed # Virtualization
sudo -u $user_name yay -S ntfs-3g exfat-utils p7zip unrar --noconfirm --needed # Files/Filesystems
sudo -u $user_name yay -S downgrade neofetch --noconfirm --needed # Command Line

# Services
systemctl enable gdm.service
systemctl enable NetworkManager.service

# Pull config files
curl https://raw.githubusercontent.com/jmauss/Arch-Install/master/.zshrc -o /home/$user_name/.zshrc

# Set up folders
xdg-user-dirs-update

# Fix Shortcuts
mkdir -p /home/$user_name/.local/share/applications
cp /usr/share/applications/{avahi-discover,bssh,bvnc,org.gnome.Cheese,qv4l2,qvidcap}.desktop /home/$user_name/.local/share/applications/
echo "NoDisplay=true" | tee -a /home/$user_name/.local/share/applications/*.desktop

# Fix permissions
chown -R $user_name:wheel /home/$user_name/

# Cleanup
sudo -u $user_name yay -Yc --noconfirm
sudo -u $user_name yay -Sc --noconfirm

rm /home/$user_name/.bash*
rm -r *
poweroff
