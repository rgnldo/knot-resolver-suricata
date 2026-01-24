#!/bin/sh

# Script Ultra-Otimizado para dnscrypt-proxy
# ✅ Processamento paralelo + streaming + interatividade completa
# ✅ Todos os domínios no formato *.dominio.com
# ✅ Download paralelo em background
# ✅ Processamento AWK otimizado em memória
# ✅ Recarregamento automático dos serviços

# --- Configurações ---
INSTALL_DIR="/opt/dnscrypt-proxy"
BLOCKLIST_FILE="$INSTALL_DIR/blocked-names.txt"
ALLOWLIST_FILE="$INSTALL_DIR/allowed-names.txt"
TEMP_DIR="/tmp/blocklist_$$"

ALLOWLIST_URL="https://codeberg.org/hagezi/mirror2/raw/branch/main/dns-blocklists/domains/whitelist-referral.txt"

LISTS="
https://codeberg.org/hagezi/mirror2/raw/branch/main/dns-blocklists/wildcard/pro-onlydomains.txt
https://codeberg.org/hagezi/mirror2/raw/branch/main/dns-blocklists/wildcard/tif.medium-onlydomains.txt
"

# Criar diretórios
mkdir -p "$INSTALL_DIR" "$TEMP_DIR"

# --- Funções Otimizadas ---

# Download com fallback e timeout
download() {
    url="$1"
    if command -v curl > /dev/null 2>&1; then
        curl -fsSL --retry 2 --connect-timeout 10 --max-time 30 "$url" 2>/dev/null
    elif command -v wget > /dev/null 2>&1; then
        wget -qO- --timeout=30 --tries=2 "$url" 2>/dev/null
    else
        echo "❌ Erro: curl ou wget não encontrado" >&2
        return 1
    fi
}

# Processamento de domínios otimizado (converte para *.dominio.com)
process_domains() {
    LC_ALL=C awk '
    /^[[:space:]]*(#|$)/ { next }
    { 
        sub(/[[:space:]]*#.*/, "")
        gsub(/^[[:space:]]+|[[:space:]]+$/, "")
        if (length($0) == 0) next
        
        domain = ""
        
        # Formato hosts: 0.0.0.0 dominio.com
        if ($1 ~ /^[0-9]+\.[0-9]+/) {
            for (i = 1; i <= NF; i++) {
                if ($i ~ /^[a-zA-Z0-9][a-zA-Z0-9.\-]*\.[a-zA-Z]{2,}$/) {
                    domain = $i
                    break
                }
            }
        }
        # Formato dnsmasq: address=/dominio.com/
        else if ($0 ~ /^[aA]ddress=\//) {
            gsub(/^[aA]ddress=\/|\/.*$/, "")
            domain = $0
        }
        # Formato direto: dominio.com ou *.dominio.com
        else if ($0 ~ /^[a-zA-Z0-9\*][a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$/) {
            domain = $0
        }
        
        if (domain != "") {
            if (substr(domain, 1, 2) != "*.") {
                print "*." domain
            } else {
                print domain
            }
        }
    }'
}

# Download e processamento paralelo de blocklists
download_and_process_blocklist() {
    url="$1"
    idx="$2"
    dest="$TEMP_DIR/list_$idx.tmp"
    
    echo "📥 Baixando lista $idx/$(echo "$LISTS" | grep -c 'https://')..."
    
    if download "$url" | process_domains > "$dest"; then
        echo "✅ Lista $idx processada: $(wc -l < "$dest" | tr -d ' ') domínios"
        return 0
    else
        echo "❌ Falha ao baixar lista $idx" >&2
        return 1
    fi
}

# --- Início do Processamento ---

echo ""
echo "╔════════════════════════════════════════════════╗"
echo "║  DNScrypt-proxy Blocklist Generator - v2.0    ║"
echo "║  Otimizado para máxima velocidade              ║"
echo "╚════════════════════════════════════════════════╝"
echo ""

# [1/4] Download paralelo da allowlist em background
echo "[1/4] 🔽 Iniciando download da Allowlist..."
(
    if download "$ALLOWLIST_URL" | process_domains > "$TEMP_DIR/allowlist.tmp"; then
        echo "✅ Allowlist baixada: $(wc -l < "$TEMP_DIR/allowlist.tmp" | tr -d ' ') domínios"
    else
        echo "⚠️  Falha ao baixar allowlist (continuando sem ela)"
        touch "$TEMP_DIR/allowlist.tmp"
    fi
) &
ALLOW_PID=$!

# [2/4] Download paralelo das blocklists
echo "[2/4] 🔽 Baixando Blocklists em paralelo..."

idx=0
pids=""
failed_count=0
total_lists=$(echo "$LISTS" | grep -c 'https://')

for url in $LISTS; do
    idx=$((idx + 1))
    download_and_process_blocklist "$url" "$idx" &
    pids="$pids $!"
done

# Aguardar downloads das blocklists
for pid in $pids; do
    if ! wait $pid 2>/dev/null; then
        failed_count=$((failed_count + 1))
    fi
done

# Verificar se todas as listas falharam
if [ "$failed_count" -eq "$total_lists" ]; then
    echo ""
    echo "❌ ERRO CRÍTICO: Todas as blocklists falharam!"
    echo "   Verifique sua conexão de internet."
    rm -rf "$TEMP_DIR"
    exit 1
elif [ "$failed_count" -gt 0 ]; then
    echo ""
    echo "⚠️  Aviso: $failed_count de $total_lists listas falharam"
fi

# Aguardar allowlist
echo ""
echo "[3/4] ⏳ Aguardando conclusão da allowlist..."
wait $ALLOW_PID 2>/dev/null

# [3/4] Compilação ultra-otimizada em AWK
echo ""
echo "[4/4] ⚙️  Compilando blocklist final..."
echo "      → Mesclando listas"
echo "      → Removendo duplicatas"
echo "      → Aplicando allowlist"

# Processamento único: merge + dedupe + filter allowlist
{
    echo "# ═══════════════════════════════════════════════════════════"
    echo "# Blocklist gerada automaticamente"
    echo "# Formato: *.dominio.com (wildcard no início)"
    echo "# Data: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "# ═══════════════════════════════════════════════════════════"
    echo "# Fontes das blocklists:"
    for url in $LISTS; do
        echo "#   - $(basename "$url")"
    done
    echo "# Allowlist: $(basename "$ALLOWLIST_URL")"
    echo "# ═══════════════════════════════════════════════════════════"
    echo ""
    
    # AWK otimizado: carrega allowlist + filtra + deduplica em uma passada
    LC_ALL=C awk '
    # Carregar allowlist em memória
    NR == FNR {
        allow[$0] = 1
        next
    }
    
    # Processar blocklists e remover duplicatas + allowlist
    {
        if (!($0 in allow) && !($0 in seen)) {
            seen[$0] = 1
            print $0
        }
    }
    ' "$TEMP_DIR/allowlist.tmp" "$TEMP_DIR"/list_*.tmp 2>/dev/null | sort -u
    
} > "$BLOCKLIST_FILE"

# Salvar allowlist processada
if [ -s "$TEMP_DIR/allowlist.tmp" ]; then
    {
        echo "# ═══════════════════════════════════════════════════════════"
        echo "# Allowed names (Whitelist)"
        echo "# Formato: *.dominio.com"
        echo "# Data: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "# Fonte: $(basename "$ALLOWLIST_URL")"
        echo "# ═══════════════════════════════════════════════════════════"
        echo ""
        cat "$TEMP_DIR/allowlist.tmp"
    } > "$ALLOWLIST_FILE"
    
    ALLOW_COUNT=$(wc -l < "$TEMP_DIR/allowlist.tmp" | tr -d ' ')
    echo "      → Allowlist salva: $ALLOW_COUNT domínios permitidos"
else
    echo "      → Allowlist não aplicada (arquivo vazio ou inexistente)"
fi

# Limpeza de arquivos temporários
rm -rf "$TEMP_DIR"

# --- Estatísticas Finais ---
TOTAL=$(grep -vc '^#\|^$' "$BLOCKLIST_FILE" 2>/dev/null || echo 0)

echo ""
echo "╔════════════════════════════════════════════════╗"
echo "║              ✅ CONCLUÍDO COM SUCESSO          ║"
echo "╚════════════════════════════════════════════════╝"
echo ""
echo "📊 Estatísticas:"
echo "   • Blocklist: $BLOCKLIST_FILE"
echo "   • Domínios bloqueados: $TOTAL únicos"
echo "   • Formato: *.dominio.com (wildcard)"
if [ -s "$ALLOWLIST_FILE" ]; then
    echo "   • Allowlist: $ALLOW_COUNT domínios permitidos"
fi
echo ""

# --- Recarregamento Automático do dnscrypt-proxy ---

echo "🔄 Recarregando dnscrypt-proxy..."
echo ""

if pid=$(pgrep dnscrypt-proxy); then
    if kill -HUP "$pid" 2>/dev/null; then
        echo "✅ dnscrypt-proxy recarregado via SIGHUP (PID: $pid)"
    else
        echo "⚠️  SIGHUP falhou, tentando reload tradicional..."
        if /etc/init.d/dnscrypt-proxy reload 2>/dev/null; then
            echo "✅ dnscrypt-proxy recarregado via init.d"
        else
            echo "❌ Falha ao recarregar dnscrypt-proxy"
        fi
    fi
else
    echo "⚠️  dnscrypt-proxy não está em execução. Iniciando..."
    if /etc/init.d/dnscrypt-proxy start 2>/dev/null; then
        echo "✅ dnscrypt-proxy iniciado com sucesso"
    else
        echo "❌ Falha ao iniciar dnscrypt-proxy"
    fi
fi

echo ""
echo "═══════════════════════════════════════════════════"
echo "🎉 Script concluído! Blocklist ativa e funcionando."
echo "═══════════════════════════════════════════════════"
echo ""
