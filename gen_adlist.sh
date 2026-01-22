#!/bin/sh

# --- Configurações ---
INSTALL_DIR="/opt/dnscrypt-proxy"
BLOCKLIST_FILE="$INSTALL_DIR/blocked-names.txt"
ALLOWLIST_FILE="$INSTALL_DIR/allowed-names.txt"

ALLOWLIST_URL="https://codeberg.org/hagezi/mirror2/raw/branch/main/dns-blocklists/domains/whitelist-referral.txt"

LISTS="
https://codeberg.org/hagezi/mirror2/raw/branch/main/dns-blocklists/wildcard/pro-onlydomains.txt
https://codeberg.org/hagezi/mirror2/raw/branch/main/dns-blocklists/wildcard/tif.medium-onlydomains.txt
"

# Arquivos Temporários
TEMP_ALLOW="/tmp/allowlist_mem.txt"
TEMP_RAW="/tmp/blocklist_raw.txt"

# --- Funções ---
download() {
    if command -v curl > /dev/null 2>&1; then
        curl -fsSL --connect-timeout 10 "$1"
    else
        wget -qO- "$1"
    fi
}

echo "[1/4] Baixando Allowlist..."
download "$ALLOWLIST_URL" | LC_ALL=C awk '
    /^[[:space:]]*(#|$)/ { next }
    { 
        sub(/[[:space:]]*#.*/, ""); 
        gsub(/^[[:space:]]+|[[:space:]]+$/, "");
        if (length($0)) {
            if (substr($0, 1, 2) == "*.") print $0;
            else print "*." $0;
        }
    }' > "$TEMP_ALLOW"

echo "[2/4] Baixando Blocklists..."
> "$TEMP_RAW"
for url in $LISTS; do
    download "$url" >> "$TEMP_RAW"
done

echo "[3/4] Compilando (Processamento Único)..."
# OTIMIZAÇÃO PRINCIPAL: Tudo em um único AWK (parse + filter + dedupe)
LC_ALL=C awk '
    # Carregar allowlist
    NR == FNR {
        allow[$0] = 1
        next
    }
    # Processar blocklist
    /^[[:space:]]*(#|$)/ { next }
    { 
        sub(/[[:space:]]*#.*/, ""); 
        gsub(/^[[:space:]]+|[[:space:]]+$/, "");
        domain = ""
    }
    $1 ~ /^[0-9]+\.[0-9]+/ { domain = $2 }
    $0 ~ /^[aA]ddress=\// { split($0, a, "/"); domain = a[2] }
    $0 ~ /^[a-zA-Z0-9\*]/ && domain == "" { domain = $0 }
    
    domain != "" {
        if (substr(domain, 1, 2) != "*.") domain = "*." domain
        # DEDUPLICAÇÃO EM MEMÓRIA (evita sort externo)
        if (!(domain in allow) && !(domain in seen)) {
            seen[domain] = 1
            print domain
        }
    }
' "$TEMP_ALLOW" "$TEMP_RAW" > "$BLOCKLIST_FILE.tmp"

echo "[4/4] Finalizando..."
{
    echo "# Blocklist gerada em: $(date)"
    echo "# Formato: *.dominio.com"
    cat "$BLOCKLIST_FILE.tmp"
} > "$BLOCKLIST_FILE"

cp "$TEMP_ALLOW" "$ALLOWLIST_FILE"
rm -f "$TEMP_ALLOW" "$TEMP_RAW" "$BLOCKLIST_FILE.tmp"

TOTAL=$(grep -c '^*\.' "$BLOCKLIST_FILE")
echo "✓ Sucesso! $TOTAL domínios únicos bloqueados."
