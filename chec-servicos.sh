#!/bin/bash

# Caminho do script principal
SCRIPT_NAME="/usr/local/bin/chec"

# Conteúdo do script principal
SCRIPT_CONTENT='#!/bin/bash

# Definindo cores
GREEN="\033[0;32m"
NC="\033[0m" # Sem cor

services=(
    crowdsec-blocklist-mirror.service
    crowdsec-firewall-bouncer.service
    crowdsec.service
    pihole-FTL.service
    openvpn.service
    squid.service
    openvpn@server.service
    wg-quick@wg0.service
    dnscrypt-proxy.service
    atlz.service
)

for service in "${services[@]}"; do
    status=$(systemctl is-active "$service")
    if [ "$status" = "active" ]; then
        echo -e "$service está ${GREEN}ativo${NC}."
    else
        echo "$service não está ativo."
    fi
done
'

# Função para instalar o script
install_script() {
    echo "Instalando o script..."

    # Cria o script em /usr/local/bin/chec
    echo "$SCRIPT_CONTENT" > "$SCRIPT_NAME"
    chmod +x "$SCRIPT_NAME"

    # Cria o link simbólico
    ln -sf "$SCRIPT_NAME" /usr/local/bin/chec

    echo "Instalação concluída. Você pode usar o comando 'chec' para verificar o status dos serviços."
}

# Função para desinstalar o script
uninstall_script() {
    if [ -f "$SCRIPT_NAME" ]; then
        echo "Removendo o script..."
        rm -f "$SCRIPT_NAME"
        rm -f /usr/local/bin/chec
        echo "O script foi removido com sucesso."
    else
        echo "O script não está instalado."
    fi
}

# Menu interativo
while true; do
    echo "========================"
    echo "  Instalador Interativo"
    echo "========================"
    echo "Escolha uma opção:"
    echo "1) Instalar o script"
    echo "2) Desinstalar o script"
    echo "3) Sair"
    read -rp "Opção: " option

    case $option in
        1)
            install_script
            ;;
        2)
            uninstall_script
            ;;
        3)
            echo "Saindo..."
            break
            ;;
        *)
            echo "Opção inválida. Tente novamente."
            ;;
    esac
done

