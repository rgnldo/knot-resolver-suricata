#!/bin/sh

IPSET_INCOMING_NAME="incoming_blocklist"
IPSET_OUTGOING_NAME="outgoing_blocklist"
CHECK_HOST="1.1.1.1"  # DNS da Cloudflare

# Função para verificar a existência de comandos
command_exists() {
  type "$1" >/dev/null 2>&1 || { echo >&2 "Comando '$1' não encontrado."; return 1; }
}

# Função para verificar a conectividade com a internet
check_internet() {
  MAX_RETRIES=5
  i=1
  while [ $i -le $MAX_RETRIES ]; do
    if ping -c 1 -W 1 "$CHECK_HOST" >/dev/null 2>&1; then
      echo "Conexão com a internet detectada. Continuando com o script..."
      return 0
    fi
    echo "Tentativa $i de $MAX_RETRIES de conexão..."
    sleep 10  # Aguarda 10 segundos antes de tentar novamente
    i=$(expr $i + 1)
  done
  echo "Falha ao estabelecer conectividade após $MAX_RETRIES tentativas. Saindo."
  exit 1
}

# Chama a função de verificação da internet
check_internet

# Verifica se os comandos necessários existem
for cmd in curl grep ipset iptables; do
  if ! command_exists "$cmd"; then
    echo >&2 "Erro: comando '$cmd' não encontrado."
    exit 1
  fi
done

# Cria ou limpa os ipsets
for ipset_name in "$IPSET_INCOMING_NAME" "$IPSET_OUTGOING_NAME"; do
  if ! ipset list -n | grep -q "$ipset_name"; then
    ipset create "$ipset_name" hash:net
  else
    ipset flush "$ipset_name"
  fi
done

# Define a lista de URLs para blocklists de entrada
cat <<EOF > /tmp/incoming_urls.txt
https://rules.emergingthreats.net/fwrules/emerging-Block-IPs.txt
https://s3.i02.estaleiro.serpro.gov.br/blocklist/blocklist.txt
https://talosintelligence.com/documents/ip-blacklist
https://iplists.firehol.org/files/alienvault_reputation.ipset
https://iplists.firehol.org/files/spamhaus_drop.netset
https://iplists.firehol.org/files/spamhaus_edrop.netset
https://iplists.firehol.org/files/ransomware_cryptowall_ps.ipset
https://iplists.firehol.org/files/ransomware_feed.ipset
https://iplists.firehol.org/files/normshield_all_ddosbot.ipset
https://blocklist.greensnow.co/greensnow.txt
EOF

# Baixa e adiciona IPs às blocklists de entrada
while read -r url; do
  echo "Obtendo dados de: $url"
  curl -s "$url" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}(\/[0-9]{1,2})?' | \
    grep -Ev '^(0\.0\.0\.0|10\.|127\.|172\.1[6-9]\.|172\.2[0-9]\.|172\.3[0-1]\.|192\.168\.)' | \
    while read -r ip; do
      ipset add -! "$IPSET_INCOMING_NAME" "$ip"
    done
done < /tmp/incoming_urls.txt

# Define a lista de URLs para blocklists de saída
cat <<EOF > /tmp/outgoing_urls.txt
https://cpdbl.net/lists/sslblock.list
https://cpdbl.net/lists/ipsum.list
EOF

# Baixa e adiciona IPs às blocklists de saída
while read -r url; do
  echo "Obtendo dados de: $url"
  curl -s "$url" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}(\/[0-9]{1,2})?' | \
    grep -Ev '^(0\.0\.0\.0|10\.|127\.|172\.1[6-9]\.|172\.2[0-9]\.|172\.3[0-1]\.|192\.168\.)' | \
    while read -r ip; do
      ipset add -! "$IPSET_OUTGOING_NAME" "$ip"
    done
done < /tmp/outgoing_urls.txt

# Função para adicionar regras de bloqueio
add_block_rules() {
  local chain="$1"
  local ipset_name="$2"
  local log_rule="-A $chain -m set --match-set $ipset_name src -j LOG --log-prefix 'BLOCKED_$chain: ' --log-level 4"
  local drop_rule="-A $chain -m set --match-set $ipset_name src -j DROP"
  
  # Adiciona a regra de LOG se não existir
  if ! iptables-save | grep -qFx -- "$log_rule"; then
    iptables -A "$chain" -m set --match-set "$ipset_name" src -j LOG --log-prefix "BLOCKED_$chain: " --log-level 4
    echo "Regra de LOG adicionada para $chain."
  else
    echo "Regra de LOG já existe para $chain."
  fi
  
  # Adiciona a regra de DROP se não existir
  if ! iptables-save | grep -qFx -- "$drop_rule"; then
    iptables -A "$chain" -m set --match-set "$ipset_name" src -j DROP
    echo "Regra de DROP adicionada para $chain."
  else
    echo "Regra de DROP já existe para $chain."
  fi
}

# Adiciona regras para blocklists de entrada
add_block_rules INPUT "$IPSET_INCOMING_NAME"

# Adiciona regras para blocklists de saída
add_block_rules OUTPUT "$IPSET_OUTGOING_NAME"

echo "Regras de bloqueio configuradas com sucesso."

# Verifica o número de IPs nos ipsets
echo "Total de IPs na blocklist de entrada: $(ipset list "$IPSET_INCOMING_NAME" | grep 'Number of entries' | awk '{print $4}')"
echo "Total de IPs na blocklist de saída: $(ipset list "$IPSET_OUTGOING_NAME" | grep 'Number of entries' | awk '{print $4}')"

# Limpa os arquivos temporários
rm -f /tmp/incoming_urls.txt /tmp/outgoing_urls.txt
