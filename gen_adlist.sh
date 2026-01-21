#!/bin/sh

# Configurações
INSTALL_DIR="/opt/dnscrypt-proxy"
BLOCKLIST_FILE="$INSTALL_DIR/blocked-names.txt"
ALLOWLIST_FILE="$INSTALL_DIR/allowed-names.txt"
ALLOWLIST_URL="https://codeberg.org/hagezi/mirror2/raw/branch/main/dns-blocklists/domains/whitelist-referral.txt"

LISTS="
https://codeberg.org/hagezi/mirror2/raw/branch/main/dns-blocklists/wildcard/pro-onlydomains.txt
https://codeberg.org/hagezi/mirror2/raw/branch/main/dns-blocklists/wildcard/tif.medium-onlydomains.txt
"

TEMP_RAW="/tmp/dns_raw.txt"
TEMP_ALLOW="/tmp/dns_allow.txt"
mkdir -p "$INSTALL_DIR"

# Função de download otimizada
download_list() {
    if command -v curl >/dev/null; then
        curl -fsSL --connect-timeout 10 "$1"
    else
        wget -qO- "$1"
    fi
}

echo "📥 Baixando listas (isso pode levar alguns segundos)..."

# 1. Baixar Allowlist e já normalizar para *.domínio
download_list "$ALLOWLIST_URL" | awk '
    /^[[:space:]]*(#|$)/ { next }
    { 
        sub(/[[:space:]]*#.*/, ""); 
        gsub(/^[[:space:]]+|[[:space:]]+$/, "");
        if (length($0)) {
            if (substr($0, 1, 2) == "*.") print $0;
            else print "*." $0;
        }
    }' > "$TEMP_ALLOW"

# 2. Baixar Blocklists e concatenar em um único temporário
> "$TEMP_RAW"
for url in $LISTS; do
    download_list "$url" >> "$TEMP_RAW"
done

echo "⚙️ Processando e filtrando domínios..."

# 3. O "Pulo do Gato": Processar tudo em um único AWK
# Carregamos a allowlist na memória e filtramos a blocklist em um único passo
LC_ALL=C awk '
    # Passo 1: Carregar allowlist (primeiro arquivo)
    NR == FNR {
        allow[$0] = 1
        next
    }
    # Passo 2: Processar blocklist (restante dos arquivos)
    /^[[:space:]]*(#|$)/ { next }
    { 
        sub(/[[:space:]]*#.*/, ""); 
        gsub(/^[[:space:]]+|[[:space:]]+$/, "");
        domain = ""
    }
    # Extração de domínio (Hosts, Dnsmasq ou Direto)
    $1 ~ /^[0-9]+\.[0-9]+/ { domain = $2 }
    $0 ~ /^[aA]ddress=\// { split($0, a, "/"); domain = a[2] }
    $0 ~ /^[a-zA-Z0-9\*]/ && domain == "" { domain = $0 }
    
    domain != "" {
        if (substr(domain, 1, 2) != "*.") domain = "*." domain
        # Só imprime se NÃO estiver na allowlist
        if (!(domain in allow)) {
            print domain
        }
    }
' "$TEMP_ALLOW" "$TEMP_RAW" | sort -u > "$BLOCKLIST_FILE.tmp"

# 4. Finalização
mv "$TEMP_ALLOW" "$ALLOWLIST_FILE"
{
    echo "# Gerado em: $(date)"
    cat "$BLOCKLIST_FILE.tmp"
} > "$BLOCKLIST_FILE"

rm -f "$TEMP_RAW" "$BLOCKLIST_FILE.tmp"

TOTAL=$(wc -l < "$BLOCKLIST_FILE")
echo "✅ Concluído! Total de domínios bloqueados: $TOTAL"

# 5. Recarregar serviço (Lógica OpenWrt + Fallback Linux)
echo "🔄 Recarregando DNSCrypt..."
if command -v /etc/init.d/dnscrypt-proxy >/dev/null; then
    /etc/init.d/dnscrypt-proxy reload
elif pidof dnscrypt-proxy >/dev/null; then
    kill -HUP $(pidof dnscrypt-proxy)
fi
