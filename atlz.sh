#!/bin/bash

## pacote necessário para oscript: apt install needrestart

TEXT_RESET='\e[0m'
TEXT_YELLOW='\e[0;33m'
TEXT_RED_B='\e[1;31m'

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

# Função para verificar se há processos apt ou dpkg em execução
check_apt_process() {
    if pgrep -x "apt" > /dev/null || pgrep -x "apt-get" > /dev/null || pgrep -x "dpkg" > /dev/null; then
        echo "Processos apt/apt-get/dpkg estão em execução. Aguarde até que todos os processos sejam concluídos."
        exit 1
    fi
}

# Função para remover arquivos de bloqueio
remove_lock_files() {
    echo "Removendo arquivos de bloqueio..."
    sudo rm -f /var/lib/dpkg/lock-frontend
    sudo rm -f /var/lib/dpkg/lock
    sudo rm -f /var/cache/apt/archives/lock
}

# Função para reconfigurar pacotes e atualizar a lista de pacotes
reconfigure_and_update() {
    echo "Reconfigurando pacotes..."
    sudo dpkg --configure -a

    echo "Atualizando a lista de pacotes..."
    sudo apt-get update
}

# Verificar se há processos apt/dpkg em execução
check_apt_process

# Remover arquivos de bloqueio
remove_lock_files

# Reconfigurar pacotes e atualizar a lista de pacotes
reconfigure_and_update

echo "Arquivos de bloqueio removidos e pacotes reconfigurados com sucesso."

apt update
echo -e $TEXT_YELLOW
echo 'APT update finalizado...'
echo -e $TEXT_RESET

apt upgrade -y
echo -e $TEXT_YELLOW
echo 'APT upgrade finalizado...'
echo -e $TEXT_RESET

apt full-upgrade -y
echo -e $TEXT_YELLOW
echo 'APT distributive upgrade finalizado...'
echo -e $TEXT_RESET

apt --fix-broken install  -y && dpkg --configure -a
echo -e $TEXT_YELLOW
echo 'APT Fix-broken finalizado...'
echo -e $TEXT_RESET

apt autoremove --purge -y && apt autoremove --purge $(deborphan) -y
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
