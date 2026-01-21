#!/bin/sh

# Script para OpenWrt - Gerar blocked-names.txt + allowed-names.txt
# ➤ REINICIA A LISTA DO ZERO A CADA EXECUÇÃO
# ➤ TODOS os domínios bloqueados são convertidos para formato: *.dominio.com
# ➤ SEM REGEX, SEM DOMÍNIOS EXATOS — apenas wildcards no início
# ➤ Recarrega dnsmasq e dnscrypt-proxy via SIGHUP
# ✅ Usa allowlist (allowed-names.txt) — formato preservado (compara como *.dominio.com)

BLOCKLIST_FILE="/opt/dnscrypt-proxy/blocked-names.txt"
ALLOWLIST_FILE="/opt/dnscrypt-proxy/allowed-names.txt"
TEMP_FILE="/tmp/blocklist_temp.txt"
RAW_LISTS="/tmp/raw_lists.txt"
ALLOWLIST_URL="https://codeberg.org/hagezi/mirror2/raw/branch/main/dns-blocklists/domains/whitelist-referral.txt"
ALLOWLIST_TEMP="/tmp/allowlist_temp.txt"

# URLs das blocklists públicas
LISTS="
https://codeberg.org/hagezi/mirror2/raw/branch/main/dns-blocklists/wildcard/pro-onlydomains.txt
https://codeberg.org/hagezi/mirror2/raw/branch/main/dns-blocklists/wildcard/tif.medium-onlydomains.txt
"

# Criar diretórios
mkdir -p "$(dirname "$BLOCKLIST_FILE")"

# ⚠️ APAGAR LISTA ANTIGA — REINICIAR DO ZERO
> "$BLOCKLIST_FILE"
> "$ALLOWLIST_FILE"

# Criar novo cabeçalho dinâmico
{
    echo "# Blocklist gerada automaticamente"
    echo "# Todos os domínios convertidos para formato: *.dominio.com"
    echo "# Updated: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "# Fontes:"
    for url in $LISTS; do
        echo "# - $url"
    done
    echo "# Allowlist: $ALLOWLIST_URL"
    echo "####################################"
    echo ""
} > "$TEMP_FILE"

# Limpar temporários
rm -f "$RAW_LISTS" "$ALLOWLIST_TEMP"
touch "$RAW_LISTS"

# Função de download (curl + wget fallback)
download_list() {
    url="$1"
    dest="${2:-$RAW_LISTS}"
    echo "Baixando: $(basename "$url")"

    if command -v curl > /dev/null 2>&1; then
        if curl -fsSL --retry 3 --connect-timeout 10 "$url" >> "$dest" 2>/dev/null; then
            return 0
        fi
    fi

    if command -v wget > /dev/null 2>&1; then
        if wget -qO- --no-check-certificate "$url" >> "$dest" 2>/dev/null; then
            return 0
        fi
    fi

    echo "❌ Falha ao baixar: $url" >&2
    return 1
}

# Baixar allowlist
echo "📥 Baixando allowlist..."
if ! download_list "$ALLOWLIST_URL" "$ALLOWLIST_TEMP"; then
    echo "⚠️  Falha ao baixar allowlist. Continuando sem ela (não recomendado)."
fi

# Baixar blocklists
FAILED=0
TOTAL_LISTS=0
for url in $LISTS; do
    TOTAL_LISTS=$((TOTAL_LISTS + 1))
    if ! download_list "$url"; then
        FAILED=$((FAILED + 1))
    fi
    echo "" >> "$RAW_LISTS"
done

# Abortar se todas as blocklists falharem
if [ "$FAILED" -eq "$TOTAL_LISTS" ]; then
    echo "❌ Todas as blocklists falharam. Abortando."
    rm -f "$RAW_LISTS" "$ALLOWLIST_TEMP"
    exit 1
fi

# Extrair e converter TUDO para formato *.dominio.com
awk '
/^[[:space:]]*(#|$)/ { next }
/#/ { sub(/#.*/, "") }
{ gsub(/^[[:space:]]+|[[:space:]]+$/, "") }
length($0) == 0 { next }

# Formato hosts: 0.0.0.0 dominio.com → extrair e converter
/^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+[[:space:]]+/ {
    for (i = 1; i <= NF; i++) {
        if ($i ~ /^[a-zA-Z0-9][a-zA-Z0-9.\-]*\.[a-zA-Z]{2,}$/) {
            if (substr($i, 1, 2) != "*.") {
                print "*." $i
            } else {
                print $i
            }
            break
        }
    }
    next
}

# Formato dnsmasq: address=/dominio.com/ → extrair e converter
/^[aA]ddress=\/[a-zA-Z0-9\*][a-zA-Z0-9.\-]*\.[a-zA-Z]/ {
    gsub(/^[aA]ddress=\/|\/.*$/, "")
    if ($0 ~ /^[a-zA-Z0-9][a-zA-Z0-9.\-]*\.[a-zA-Z]{2,}$/) {
        if (substr($0, 1, 2) != "*.") {
            print "*." $0
        } else {
            print $0
        }
    }
    next
}

# Formato direto: dominio.com ou *.dominio.com
/^[a-zA-Z0-9\*][a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$/ {
    if (substr($0, 1, 2) == "*.") {
        print $0
    } else {
        print "*." $0
    }
    next
}
' "$RAW_LISTS" | sort -u >> "$TEMP_FILE"

# Carregar allowlist (se existir) e converter também para *.dominio.com para comparação
if [ -s "$ALLOWLIST_TEMP" ]; then
    # Processar allowlist: converter tudo para *.dominio.com
    awk '
    /^[[:space:]]*(#|$)/ { next }
    /#/ { sub(/#.*/, "") }
    { gsub(/^[[:space:]]+|[[:space:]]+$/, ""); if (length($0)) print }
    ' "$ALLOWLIST_TEMP" | awk '
    {
        if (substr($0, 1, 2) == "*.") {
            print $0
        } else {
            print "*." $0
        }
    }' > "${ALLOWLIST_TEMP}.clean"

    # Aplicar allowlist: remover do blocklist entradas idênticas (no formato *.dominio.com)
    awk '
    BEGIN {
        while ((getline line < "'"${ALLOWLIST_TEMP}.clean"'") > 0) {
            allowlist[line] = 1
        }
        close("'"${ALLOWLIST_TEMP}.clean"'")
    }
    /^#/ { print; next }
    !($0 in allowlist)
    ' "$TEMP_FILE" | sort -u > "${TEMP_FILE}.filtered"

    mv "${TEMP_FILE}.filtered" "$TEMP_FILE"
    ALLOW_COUNT=$(wc -l < "${ALLOWLIST_TEMP}.clean" | tr -d ' ')
    echo "✅ Allowlist aplicada: $ALLOW_COUNT entradas idênticas removidas (comparadas como *.dominio.com)."
else
    echo "⚠️  Allowlist não aplicada (download falhou ou vazia)."
    # Apenas ordenar e remover duplicatas
    awk '
    /^#/ { print; next }
    !seen[$0]++
    ' "$TEMP_FILE" | sort -u > "${TEMP_FILE}.sorted" && mv "${TEMP_FILE}.sorted" "$TEMP_FILE"
fi

# Salvar allowlist processada (convertida para *.dominio.com)
if [ -s "${ALLOWLIST_TEMP}.clean" ]; then
    {
        echo "# Allowed names (allowlist) - convertida para *.dominio.com"
        echo "# Updated: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "# Source: $ALLOWLIST_URL"
        echo ""
        cat "${ALLOWLIST_TEMP}.clean"
    } > "$ALLOWLIST_FILE"
    echo "✅ allowed-names.txt atualizado (formato *.dominio.com)."
else
    echo "⚠️  allowed-names.txt não atualizado."
fi

# Substituir lista final — TOTALMENTE NOVA, TODOS OS DOMÍNIOS EM *.dominio.com
mv "$TEMP_FILE" "$BLOCKLIST_FILE"

# Limpar temporários
rm -f "$RAW_LISTS" "$ALLOWLIST_TEMP" "${ALLOWLIST_TEMP}.clean"

# Contagem final
TOTAL=$(grep -v '^\s*#' "$BLOCKLIST_FILE" | grep -v '^\s*$' | wc -l | tr -d ' ')
echo "✓ Blocklist totalmente recriada — TODOS os domínios no formato *.dominio.com"
echo "✓ Total de entradas únicas: $TOTAL"

# Recarregar dnscrypt-proxy
if pid=$(pgrep dnscrypt-proxy); then
    kill -HUP "$pid" > /dev/null 2>&1 && \
        echo "✓ dnscrypt-proxy recarregado via SIGHUP" || \
        sudo systemctl reload dnscrypt-proxy.service
else
    echo "⚠ dnscrypt-proxy não está rodando. Iniciando..."
    sudo systemctl start dnscrypt-proxy.service
fi
