#!/bin/bash

## pacote necessário para oscript: apt install needrestart

TEXT_RESET='\e[0m'
TEXT_YELLOW='\e[0;33m'
TEXT_RED_B='\e[1;31m'

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

apt update
echo -e $TEXT_YELLOW
echo 'APT update finalizado...'
echo -e $TEXT_RESET

apt-get upgrade -y
echo -e $TEXT_YELLOW
echo 'APT upgrade finalizado...'
echo -e $TEXT_RESET

apt full-upgrade -y
echo -e $TEXT_YELLOW
echo 'APT distributive upgrade finalizado...'
echo -e $TEXT_RESET

apt -y --fix-broken install
echo -e $TEXT_YELLOW
echo 'APT Fix-broken finalizado...'
echo -e $TEXT_RESET

sudo apt-get autoremove -y
echo -e $TEXT_YELLOW
echo 'APT auto remove finalizado...'
echo -e $TEXT_RESET

if [ -f /var/run/reboot-required ]; then
    echo -e $TEXT_RED_B
    echo 'Reinicio do sistema requirido!'
    echo 'Reinicio do sistema...'
    echo -e $TEXT_RESET
    sudo systemctl reboot
else
    echo -e $TEXT_YELLOW
    echo 'Reinicio do sistema não requirido.'
    echo -e $TEXT_RESET
fi
