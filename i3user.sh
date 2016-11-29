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

useradd -c $name -m -g wheel -s /bin/zsh $user_name
passwd $user_name << EOPF
$passwd1
$passwd2
EOPF

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
chown -R $user_name:wheel i3dark.crx .zshrc .Xresources .xinitrc .zprofile .config Builds Scripts
chmod u+x Scripts/i3user.sh
cd .config/i3blocks/scripts/
chmod u+x playing sp
cd

rm /home/$user_name/.bash*
