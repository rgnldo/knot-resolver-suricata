#!/bin/sh

# --- Configurações ---
INSTALL_DIR="/opt/dnscrypt-proxy"
BLOCKLIST_FILE="$INSTALL_DIR/blocked-names.txt"
ALLOWLIST_FILE="$INSTALL_DIR/allowed-names.txt"

# URL da sua Allowlist (Whitelist)
ALLOWLIST_URL="https://codeberg.org/hagezi/mirror2/raw/branch/main/dns-blocklists/domains/whitelist-referral.txt"

# URLs das Blocklists (Fontes)
LISTS="
https://codeberg.org/hagezi/mirror2/raw/branch/main/dns-blocklists/wildcard/pro-onlydomains.txt
https://codeberg.org/hagezi/mirror2/raw/branch/main/dns-blocklists/wildcard/tif.medium-onlydomains.txt
"

# Arquivos Temporários (em RAM se /tmp for tmpfs)
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

echo "[1/4] Baixando e normalizando Allowlist..."
# Baixa e converte para *.dominio.com para comparação precisa
download "$ALLOWLIST_URL" | awk '
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

echo "[3/4] Compilando listas (Alta Performance - AWK Mode)..."
# Processamento ultra-rápido: carrega allowlist em hash e filtra blocklist
# LC_ALL=C acelera o processamento de texto em até 3x
LC_ALL=C awk '
    # Passo 1: Carregar allowlist na memoria
    NR == FNR {
        allow[$0] = 1
        next
    }
    # Passo 2: Ignorar comentarios e linhas vazias na blocklist
    /^[[:space:]]*(#|$)/ { next }
    { 
        sub(/[[:space:]]*#.*/, ""); 
        gsub(/^[[:space:]]+|[[:space:]]+$/, "");
        domain = ""
    }
    # Formato HOSTS (0.0.0.0 dominio.com)
    $1 ~ /^[0-9]+\.[0-9]+/ { domain = $2 }
    # Formato DNSMASQ (address=/dominio.com/...)
    $0 ~ /^[aA]ddress=\// { split($0, a, "/"); domain = a[2] }
    # Formato Direto (dominio.com ou *.dominio.com)
    $0 ~ /^[a-zA-Z0-9\*]/ && domain == "" { domain = $0 }
    
    domain != "" {
        # Normaliza para *.dominio.com
        if (substr(domain, 1, 2) != "*.") domain = "*." domain
        # Filtra contra a allowlist em memoria
        if (!(domain in allow)) {
            print domain
        }
    }
' "$TEMP_ALLOW" "$TEMP_RAW" | sort -u > "$BLOCKLIST_FILE.tmp"

echo "[4/4] Finalizando arquivos..."
# Adiciona cabeçalho e move para o local definitivo
{
    echo "# Blocklist gerada em: $(date)"
    echo "# Formato: *.dominio.com"
    cat "$BLOCKLIST_FILE.tmp"
} > "$BLOCKLIST_FILE"

# Salva uma copia da allowlist processada para referencia do usuario
cp "$TEMP_ALLOW" "$ALLOWLIST_FILE"

# Limpeza
rm -f "$TEMP_ALLOW" "$TEMP_RAW" "$BLOCKLIST_FILE.tmp"

TOTAL=$(wc -l < "$BLOCKLIST_FILE")
echo "✓ Sucesso! $TOTAL domínios únicos bloqueados."
