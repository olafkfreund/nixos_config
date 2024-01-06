#!/bin/sh
gnome_schema="org.gnome.desktop.interface"
gsettings set "$gnome_schema" icon-theme "Gruvbox-Plus-Dark"
gsettings set "$gnome_schema" cursor-theme "PearDarkCursors"
gsettings set "$gnome_schema" font-name "Cantarell 11"
gsettings set "$gnome_schema" color-scheme "prefer-dark"
