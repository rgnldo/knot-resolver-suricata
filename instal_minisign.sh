#!/bin/bash
# Define o URL direto para o arquivo minisign
minisign_url="https://github.com/jedisct1/minisign/releases/download/0.11/minisign-0.11-linux.tar.gz"

# Realiza o download e a extração do arquivo minisign
sudo curl -sL "$minisign_url" | tar xzf - --strip-components=1 --wildcards '*/x86_64/minisign'

# Renomeia o arquivo para 'minisign'
sudo mv x86_64/minisign .
sudo rm -rf x86_64

# Configura as permissões
sudo chmod +x minisign

# Setup auto-update script
sudo chmod +x dnscrypt-proxy-update.sh
sudo echo "0 */12 * * * /opt/dnscrypt-proxy/dnscrypt-proxy-update.sh" > /var/spool/cron/crontabs/root
