#!/bin/bash

# Script de instalação e configuração interativa

SCRIPT_URL="https://raw.githubusercontent.com/rgnldo/knot-resolver-suricata/refs/heads/master/bloqIP_list.sh"
SCRIPT_NAME="bloqIP_list.sh"
INSTALL_DIR="/usr/local/bin"
CRON_DIR="/etc/cron.d"
CRON_FILE="bloqip_cron"

# Função para instalar o script
install_script() {
    echo "Baixando o script $SCRIPT_NAME..."
    wget -q "$SCRIPT_URL" -O "$INSTALL_DIR/$SCRIPT_NAME"
    if [ $? -eq 0 ]; then
        chmod +x "$INSTALL_DIR/$SCRIPT_NAME"
        echo "Script $SCRIPT_NAME instalado com sucesso em $INSTALL_DIR."
    else
        echo "Erro ao baixar o script. Verifique a URL e a conexão com a internet."
        exit 1
    fi
}

# Função para configurar o agendamento do cron
configure_cron() {
    echo "Configurando o agendamento do cron..."

    # Criar um arquivo cron próprio
    echo "# Agendamento para executar o script bloqIP_list.sh" > "$CRON_DIR/$CRON_FILE"

    # Agendamento para executar após o boot
    echo "@reboot root $INSTALL_DIR/$SCRIPT_NAME" >> "$CRON_DIR/$CRON_FILE"

    # Agendamento para executar a cada 12 horas
    echo "0 */12 * * * root $INSTALL_DIR/$SCRIPT_NAME" >> "$CRON_DIR/$CRON_FILE"

    echo "Arquivo de cron criado com sucesso em $CRON_DIR/$CRON_FILE."
}

# Função para desinstalar o script e remover o agendamento do cron
uninstall_script() {
    echo "Desinstalando o script $SCRIPT_NAME..."
    if [ -f "$INSTALL_DIR/$SCRIPT_NAME" ]; then
        rm -f "$INSTALL_DIR/$SCRIPT_NAME"
        echo "Script $SCRIPT_NAME removido de $INSTALL_DIR."
    else
        echo "Script $SCRIPT_NAME não encontrado em $INSTALL_DIR."
    fi

    echo "Removendo o arquivo de cron..."
    if [ -f "$CRON_DIR/$CRON_FILE" ]; then
        rm -f "$CRON_DIR/$CRON_FILE"
        echo "Arquivo de cron $CRON_FILE removido de $CRON_DIR."
    else
        echo "Arquivo de cron $CRON_FILE não encontrado em $CRON_DIR."
    fi

    echo "Desinstalação concluída."
}

# Menu principal
main_menu() {
    echo "========== Menu Principal =========="
    echo "1. Instalar e configurar o script"
    echo "2. Desinstalar o script e remover o agendamento"
    echo "3. Sair"
    read -p "Escolha uma opção: " OPTION

    case $OPTION in
        1)
            install_script
            configure_cron
            echo "Instalação e configuração concluídas."
            ;;
        2)
            uninstall_script
            ;;
        3)
            echo "Saindo..."
            exit 0
            ;;
        *)
            echo "Opção inválida. Tente novamente."
            main_menu
            ;;
    esac
}

# Executar o menu principal
main_menu
