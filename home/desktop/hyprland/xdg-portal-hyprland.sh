#!/usr/bin/env bash
sleep 1
systemctl --user import-environment PATH
systemctl --user restart xdg-desktop-portal.service

