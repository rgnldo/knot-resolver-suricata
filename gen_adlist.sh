#!/bin/bash

# Cores
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

DIR="/opt/dnscrypt-proxy"
BLOCK_FILE="$DIR/blocked-names.txt"
ALLOW_URL="https://codeberg.org/hagezi/mirror2/raw/branch/main/dns-blocklists/domains/whitelist-referral.txt"
LISTS="
https://codeberg.org/hagezi/mirror2/raw/branch/main/dns-blocklists/wildcard/pro-onlydomains.txt
https://codeberg.org/hagezi/mirror2/raw/branch/main/dns-blocklists/wildcard/tif.medium-onlydomains.txt
"

echo -e "${CYAN}[Adlist]${NC} Iniciando processamento de listas..."

# Download silencioso e rápido
download() { curl -fsSL "$1"; }

# 1. Processar Allowlist em memória
echo -ne "📥 Baixando Allowlist... "
ALLOW=$(download "$ALLOW_URL" | awk '/^[[:space:]]*(#|$)/ {next} {sub(/[[:space:]]*#.*/,""); gsub(/^[[:space:]]+|[[:space:]]+$/,""); if(length($0)) { if(substr($0,1,2)=="*.") print $0; else print "*."$0 }}')
echo -e "${GREEN}OK${NC}"

# 2. Baixar e Processar Blocklists
echo -ne "📥 Processando Blocklists (Wildcard Mode)... "
(
  echo "$ALLOW" > /tmp/allow_mem.txt
  for url in $LISTS; do download "$url"; done > /tmp/raw_block.txt

  LC_ALL=C awk '
    NR==FNR { allow[$0]=1; next }
    /^[[:space:]]*(#|$)/ {next}
    { sub(/[[:space:]]*#.*/,""); gsub(/^[[:space:]]+|[[:space:]]+$/,""); dom="" }
    $1 ~ /^[0-9]+\.[0-9]+/ { dom=$2 }
    $0 ~ /^[aA]ddress=\// { split($0,a,"/"); dom=a[2] }
    $0 ~ /^[a-zA-Z0-9\*]/ && dom=="" { dom=$0 }
    dom != "" {
      if(substr(dom,1,2)!="*.") dom="*."dom
      if(!(dom in allow)) print dom
    }
  ' /tmp/allow_mem.txt /tmp/raw_block.txt | sort -u > "$BLOCK_FILE"
)
echo -e "${GREEN}OK${NC}"

# Limpeza
rm -f /tmp/allow_mem.txt /tmp/raw_block.txt

TOTAL=$(wc -l < "$BLOCK_FILE")
echo -e "${CYAN}[Adlist]${NC} Bloqueio atualizado: ${GREEN}$TOTAL${NC} domínios wildcards."
