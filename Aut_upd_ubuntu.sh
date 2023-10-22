#!/bin/bash

# Verifica se o pacote unattended-upgrades está instalado
if ! dpkg -l | grep -q unattended-upgrades; then
    echo "O pacote unattended-upgrades não está instalado. Instalando..."
    sudo apt update
    sudo apt install unattended-upgrades -y
fi

# URL do arquivo 50unattended-upgrades no GitHub
URL="https://raw.githubusercontent.com/rgnldo/knot-resolver-suricata/master/50unattended-upgrades"

# Pasta de destino
DEST_FOLDER="/etc/apt/apt.conf.d/"

# Nome do arquivo de destino
DEST_FILE="50unattended-upgrades"

# Baixa o arquivo do GitHub e o coloca na pasta de destino
sudo wget "$URL" -O "${DEST_FOLDER}${DEST_FILE}"

# Verifica se o arquivo foi baixado com sucesso
if [ $? -eq 0 ]; then
    echo "Arquivo baixado com sucesso."

    # Ativa e inicia o serviço unattended-upgrades
    sudo systemctl daemon-reload
    sudo systemctl enable unattended-upgrades.service
    sudo systemctl start unattended-upgrades.service

    echo "Serviço unattended-upgrades ativado e iniciado."
else
    echo "Falha ao baixar o arquivo."
fi
