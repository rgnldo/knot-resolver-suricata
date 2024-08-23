#!/bin/bash

install_service() {
    # Verificar se needrestart está instalado, senão instalar
    if ! dpkg -s needrestart &>/dev/null; then
        echo "Instalando needrestart..."
        sudo apt-get update && sudo apt-get install -y needrestart
    fi

    # Verificar se deborphan está instalado, senão instalar
    if ! dpkg -s deborphan &>/dev/null; then
        echo "Instalando deborphan..."
        sudo apt-get update && sudo apt-get install -y deborphan
    fi

    # Verificar se a pasta /opt/apps existe, senão criar
    if [ ! -d "/opt/apps" ]; then
        sudo mkdir -p /opt/apps
    fi

    # Baixar o script atlz.sh
    sudo curl -o $SCRIPT_PATH $SCRIPT_URL
    sudo chmod +x $SCRIPT_PATH

    # Criar o arquivo de serviço
    echo "[Unit]" > $SERVICE_FILE
    echo "Description=Script de Atualização" >> $SERVICE_FILE
    echo "" >> $SERVICE_FILE
    echo "[Install]" >> $SERVICE_FILE
    echo "WantedBy=multi-user.target" >> $SERVICE_FILE
    echo "[Service]" >> $SERVICE_FILE
    echo "Type=simple" >> $SERVICE_FILE
    echo "ExecStart=$SCRIPT_PATH" >> $SERVICE_FILE

    # Criar o arquivo do temporizador
    echo "[Unit]" > $TIMER_FILE
    echo "Description=Agendador diário para o script de atualização" >> $TIMER_FILE
    echo "" >> $TIMER_FILE
    echo "[Timer]" >> $TIMER_FILE
    echo "OnCalendar=daily" >> $TIMER_FILE
    echo "OnCalendar=02:00" >> $TIMER_FILE
    echo "Persistent=true" >> $TIMER_FILE
    echo "" >> $TIMER_FILE
    echo "[Install]" >> $TIMER_FILE
    echo "WantedBy=timers.target" >> $TIMER_FILE

    # Recarregar o systemd
    sudo systemctl daemon-reload

    # Ativar e iniciar o temporizador
    sudo systemctl enable --now atlz.timer

    # Criar o link simbólico
    sudo ln -s $SCRIPT_PATH /usr/local/bin/atlz

    echo "Serviço e temporizador criados com sucesso."
}

uninstall_service() {
    # Desativar e parar o temporizador
    sudo systemctl disable --now atlz.timer

    # Remover arquivos
    sudo rm $SCRIPT_PATH
    sudo rm $SERVICE_FILE
    sudo rm $TIMER_FILE

    # Remover o link simbólico, se existir
    if [ -L "/usr/local/bin/atlz" ]; then
        sudo rm /usr/local/bin/atlz
    fi

    echo "Serviço e temporizador removidos com sucesso."
}

# URL do script atlz.sh no repositório
SCRIPT_URL="https://raw.githubusercontent.com/rgnldo/knot-resolver-suricata/master/atlz.sh"

# Caminho onde o script atlz.sh será salvo
SCRIPT_PATH="/opt/apps/atlz.sh"

# Criar o arquivo de serviço
SERVICE_FILE="/etc/systemd/system/atlz.service"

# Criar o arquivo do temporizador
TIMER_FILE="/etc/systemd/system/atlz.timer"

while true; do
    clear
    echo "Instalação e Desinstalação do Serviço de Atualização"
    echo "-----------------------------------------------------"
    echo "1. Instalar serviço de atualização"
    echo "2. Desinstalar serviço de atualização"
    echo "3. Sair"
    read -p "Escolha uma opção: " choice

    case $choice in
        1) install_service ;;
        2) uninstall_service ;;
        3) exit ;;
        *) echo "Opção inválida. Tente novamente." ;;
    esac
done
