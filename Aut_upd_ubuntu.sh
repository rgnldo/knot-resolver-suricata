#!/bin/bash

# Função para instalar o pacote unattended-upgrades
install_unattended_upgrades() {
    echo "Instalando o pacote unattended-upgrades..."
    sudo apt update
    sudo apt install unattended-upgrades -y
}

# Função para baixar e instalar o arquivo de configuração
install_config_file() {
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
        echo "Arquivo de configuração baixado com sucesso."

        # Ativa e inicia o serviço unattended-upgrades
        sudo systemctl daemon-reload
        sudo systemctl enable unattended-upgrades.service
        sudo systemctl start unattended-upgrades.service

        echo "Serviço unattended-upgrades ativado e iniciado."
    else
        echo "Falha ao baixar o arquivo de configuração."
    fi
}

# Função para desinstalar o pacote e remover os arquivos de configuração
uninstall_and_remove() {
    echo "Desinstalando o pacote unattended-upgrades..."
    sudo apt remove unattended-upgrades --purge -y
    sudo apt autoremove -y

    # Remove o arquivo de configuração
    CONFIG_FILE="/etc/apt/apt.conf.d/50unattended-upgrades"
    if [ -f "$CONFIG_FILE" ]; then
        sudo rm "$CONFIG_FILE"
    fi

    echo "Unattended-upgrades desinstalado e arquivos de configuração removidos."
}

# Menu interativo
echo "Script de instalação e configuração do Unattended-Upgrades"
echo "Escolha uma opção:"
echo "1. Instalar o Unattended-Upgrades e configurar"
echo "2. Desinstalar o Unattended-Upgrades e remover configurações"
echo "3. Sair"

read -p "Opção: " choice

case $choice in
    1)
        install_unattended_upgrades
        install_config_file
        ;;
    2)
        uninstall_and_remove
        ;;
    3)
        echo "Saindo do script."
        ;;
    *)
        echo "Opção inválida. Saindo do script."
        ;;
esac
