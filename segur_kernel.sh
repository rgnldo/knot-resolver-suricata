#!/bin/bash

# Arquivo de configuração do sysctl
sysctl_conf_file="/etc/sysctl.d/99-sysctl.conf"

# Função para adicionar uma regra ao arquivo sysctl_conf_file
add_sysctl_rule() {
    local rule=$1
    grep -qF "$rule" "$sysctl_conf_file" || echo "$rule" >> "$sysctl_conf_file"
}

# Verificar se o arquivo de configuração já existe
if [[ -e "$sysctl_conf_file" ]]; then
    echo "O arquivo $sysctl_conf_file já existe. Verificando configurações existentes..."
else
    echo "Criando o arquivo $sysctl_conf_file..."
    touch "$sysctl_conf_file"
fi

# Regras de segurança para o kernel

# Proteção contra SYN flood
add_sysctl_rule "# Proteção contra SYN flood"
add_sysctl_rule "net.ipv4.tcp_syncookies = 1"

# Restringir a execução de páginas de memória
add_sysctl_rule "# Restringir a execução de páginas de memória"
add_sysctl_rule "vm.mmap_min_addr = 65536"

# Proteção contra estouro de buffer
add_sysctl_rule "# Proteção contra estouro de buffer"
add_sysctl_rule "kernel.randomize_va_space = 2"

# Proteção contra ataques de inundação de ICMP
add_sysctl_rule "# Proteção contra ataques de inundação de ICMP"
add_sysctl_rule "net.ipv4.icmp_echo_ignore_broadcasts =1"
add_sysctl_rule "net.ipv4.icmp_ignore_bogus_error_responses=1"

# Proteção contra ataques de negação de serviço
add_sysctl_rule "# Proteção contra ataques de negação de serviço"
add_sysctl_rule "net.ipv4.tcp_max_syn_backlog=2048"
add_sysctl_rule "net.ipv4.tcp_synack_retries=2"
add_sysctl_rule "net.ipv4.tcp_syn_retries=5"

# Limitar a taxa de abertura de conexões por segundo
add_sysctl_rule "# Limitar a taxa de abertura de conexões por segundo"
add_sysctl_rule "net.ipv4.tcp_max_syn_backlog=2048"
add_sysctl_rule "net.ipv4.tcp_synack_retries=2"
add_sysctl_rule "net.ipv4.tcp_syn_retries=5"

# Acelerar respostas ACK RTS
add_sysctl_rule "# Acelerar respostas ACK RTS"
add_sysctl_rule "net.ipv4.tcp_rfc1337=1"
add_sysctl_rule "net.ipv4.tcp_sack=1"
add_sysctl_rule "net.ipv4.tcp_timestamps=1"
add_sysctl_rule "net.ipv4.tcp_window_scaling=1"

# Outras configurações
add_sysctl_rule "# Outras configurações"
add_sysctl_rule "net.core.rmem_default=262144"
add_sysctl_rule "net.core.rmem_max=524288"
add_sysctl_rule "net.core.wmem_default=262144"
add_sysctl_rule "net.core.wmem_max=524288"
add_sysctl_rule "net.ipv4.tcp_fastopen=3"
add_sysctl_rule "net.ipv4.tcp_retries1=3"
add_sysctl_rule "net.ipv4.tcp_retries2=5"

add_sysctl_rule "# Incremento nas conexões TCP"
add_sysctl_rule "net.core.default_qdisc=fq"
add_sysctl_rule "net.ipv4.tcp_congestion_control=bbr"

# Remover linhas vazias duplicadas do arquivo sysctl_conf_file
sed -i '/^$/d' "$sysctl_conf_file"

echo "As configurações foram adicionadas ao arquivo $sysctl_conf_file."

# Reiniciar o sistema para garantir que as alterações sejam aplicadas completamente
read -p "Deseja reiniciar o sistema agora para aplicar completamente as alterações? (s/n): " choice

case "$choice" in
    s|S)
        echo "Reiniciando o sistema..."
        systemctl reboot
        ;;
    *)
        echo "Reinicie o sistema posteriormente para aplicar completamente as alterações."
        ;;
esac

exit 0
