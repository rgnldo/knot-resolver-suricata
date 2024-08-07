#!/bin/bash

# Nome do script principal
SCRIPT_NAME="/usr/local/bin/chec"

# Conteúdo do script principal
SCRIPT_CONTENT='#!/bin/bash

# Definindo cores
GREEN='\''\033[0;32m'\''
NC='\''\033[0m'\'' # Sem cor

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

# Cria o script principal no destino
echo "$SCRIPT_CONTENT" > "$SCRIPT_NAME"

# Adiciona permissões de execução
chmod +x "$SCRIPT_NAME"

echo "Instalação completa. Você pode usar o comando 'chec' para verificar o status dos serviços."
