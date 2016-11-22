#! /bin/sh

# Requires User Themes extension enabled
# Requires Gnome Tweak Tool
#
# usage:  extractGSTcss.sh theme_name

# The variable THEME_NAME is set to the value "theme_name" (the first
# parameter ${1} on the command line.

THEME_NAME=${1}

# THEME_DIR will contain the theme files from the resource file.

THEME_DIR=~/.themes/${THEME_NAME}/gnome-shell/

# Must be in the home directory.

cd ${HOME}

# Create the custom theme directory which will be name of the theme.

mkdir -p ${THEME_DIR}

# GSTGRF is the Gnome Shell Theme Resouce File
 
GSTGRF=/usr/share/gnome-shell/gnome-shell-theme.gresource

# For each resource file path in the list of resouces in the resouce file,
# set the filename to the base name in the path then extract from the resouce
# file each resource and write it to the THEME_DIR.

for res in `gresource list ${GSTGRF}`; do
        filename=`echo ${res} | sed 's/\/org\/gnome\/shell\/theme\///'`;
        gresource extract ${GSTGRF} ${res} > ${THEME_DIR}${filename};
done

# In the THEME_DIR you will find the file gnome-shell.css.
# This file can be edited to change the font family and background
# color of the calendar.

