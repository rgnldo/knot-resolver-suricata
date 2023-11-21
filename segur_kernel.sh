#!/bin/bash

# Arquivo de configuração do sysctl
sysctl_conf_file="/etc/sysctl.d/99-sysctl.conf"

# Função para detectar os valores atuais das configurações do sysctl
detect_current_sysctl_settings() {
    current_overcommit_memory=$(sysctl -n vm.overcommit_memory)
    current_overcommit_ratio=$(sysctl -n vm.overcommit_ratio)
    current_swappiness=$(sysctl -n vm.swappiness)
    current_vfs_cache_pressure=$(sysctl -n vm.vfs_cache_pressure)
    current_page_cluster=$(sysctl -n vm.page-cluster)
    current_tcp_syncookies=$(sysctl -n net.ipv4.tcp_syncookies)
    current_dirty_background_bytes=$(sysctl -n vm.dirty_background_bytes)
    current_dirty_bytes=$(sysctl -n vm.dirty_bytes)
}

# Função para obter a quantidade total de memória RAM em gigabytes
get_total_memory_gb() {
    total_memory_gb=$(awk '/MemTotal/ {printf "%.0f\n", $2/1024/1024}' /proc/meminfo)
}

# Função para verificar a quantidade de RAM e ajustar as configurações
adjust_settings_based_on_memory() {
    get_total_memory_gb

    if (( $(echo "$total_memory_gb > 16" | bc -l) )); then
        # Se a memória for maior que 16GB, ajuste as configurações
        echo "Ajustando configurações para sistema com mais de 16GB de RAM..."
        
        # Ajuste as configurações conforme necessário
        # Exemplo: aumentar vm.swappiness, vm.dirty_background_bytes, etc.
        # Adicione ou modifique conforme necessário para otimizar o desempenho.
        
        echo "vm.swappiness=10" >> "$sysctl_conf_file"
        echo "vm.dirty_background_bytes=8388608" >> "$sysctl_conf_file"
        echo "vm.dirty_bytes=16777216" >> "$sysctl_conf_file"
    else
        # Se a memória for 16GB ou menos, mantenha as configurações padrão
        echo "Configurações padrão para sistemas com 16GB ou menos de RAM."
    fi
}

# Função para aplicar as configurações desejadas
apply_sysctl_settings() {
    echo "vm.overcommit_memory=1" >> "$sysctl_conf_file"
    echo "vm.overcommit_ratio=300" >> "$sysctl_conf_file"
    echo "net.ipv4.tcp_syncookies=1" >> "$sysctl_conf_file"
    echo "vm.vfs_cache_pressure=10" >> "$sysctl_conf_file"
    echo "vm.page-cluster=0" >> "$sysctl_conf_file"
}

# Função para adicionar configurações extras de segurança
apply_security_settings() {
    # Regras de segurança para o kernel
    echo "# Proteção contra SYN flood" >> "$sysctl_conf_file"
    echo "net.ipv4.tcp_syncookies = 1" >> "$sysctl_conf_file"

    # Restringir a execução de páginas de memória
    echo "# Restringir a execução de páginas de memória" >> "$sysctl_conf_file"
    echo "vm.mmap_min_addr = 65536" >> "$sysctl_conf_file"

    # Proteção contra estouro de buffer
    echo "# Proteção contra estouro de buffer" >> "$sysctl_conf_file"
    echo "kernel.randomize_va_space = 2" >> "$sysctl_conf_file"

    # Proteção contra ataques de inundação de ICMP
    echo "# Proteção contra ataques de inundação de ICMP" >> "$sysctl_conf_file"
    echo "net.ipv4.icmp_echo_ignore_broadcasts =1" >> "$sysctl_conf_file"
    echo "net.ipv4.icmp_ignore_bogus_error_responses=1" >> "$sysctl_conf_file"

    # Proteção contra ataques de negação de serviço
    echo "# Proteção contra ataques de negação de serviço" >> "$sysctl_conf_file"
    echo "net.ipv4.tcp_max_syn_backlog=2048" >> "$sysctl_conf_file"
    echo "net.ipv4.tcp_synack_retries=2" >> "$sysctl_conf_file"
    echo "net.ipv4.tcp_syn_retries=5" >> "$sysctl_conf_file"

    # Limitar a taxa de abertura de conexões por segundo
    echo "# Limitar a taxa de abertura de conexões por segundo" >> "$sysctl_conf_file"
    echo "net.ipv4.tcp_max_syn_backlog=2048" >> "$sysctl_conf_file"
    echo "net.ipv4.tcp_synack_retries=2" >> "$sysctl_conf_file"
    echo "net.ipv4.tcp_syn_retries=5" >> "$sysctl_conf_file"

    # Acelerar respostas ACK RTS
    echo "# Acelerar respostas ACK RTS" >> "$sysctl_conf_file"
    echo "net.ipv4.tcp_rfc1337=1" >> "$sysctl_conf_file"
    echo "net.ipv4.tcp_sack=1" >> "$sysctl_conf_file"
    echo "net.ipv4.tcp_timestamps=1" >> "$sysctl_conf_file"
    echo "net.ipv4.tcp_window_scaling=1" >> "$sysctl_conf_file"

    # Outras configurações
    echo "# Outras configurações" >> "$sysctl_conf_file"
    echo "net.core.rmem_default=262144" >> "$sysctl_conf_file"
    echo "net.core.rmem_max=524288" >> "$sysctl_conf_file"
    echo "net.core.wmem_default=262144" >> "$sysctl_conf_file"
    echo "net.core.wmem_max=524288" >> "$sysctl_conf_file"
    echo "net.ipv4.tcp_fastopen=3" >> "$sysctl_conf_file"
    echo "net.ipv4.tcp_retries1=3" >> "$sysctl_conf_file"
    echo "net.ipv4.tcp_retries2=5" >> "$sysctl_conf_file"

    echo "# Incremento nas conexões TCP" >> "$sysctl_conf_file"
    echo "net.core.default_qdisc=fq" >> "$sysctl_conf_file"
    echo "net.ipv4.tcp_congestion_control=bbr" >> "$sysctl_conf_file"
}

# Função para adicionar uma regra ao arquivo de configuração sysctl
add_sysctl_rule() {
    echo "$1" >> "$sysctl_conf_file"
}

# Função para restaurar as configurações anteriores
restore_sysctl_settings() {
    sudo sysctl -w vm.overcommit_memory=$current_overcommit_memory
    sudo sysctl -w vm.overcommit_ratio=$current_overcommit_ratio
    sudo sysctl -w vm.swappiness=$current_swappiness
    sudo sysctl -w vm.vfs_cache_pressure=$current_vfs_cache_pressure
    sudo sysctl -w vm.page-cluster=$current_page_cluster
    sudo sysctl -w net.ipv4.tcp_syncookies=$current_tcp_syncookies
    sudo sysctl -w vm.dirty_background_bytes=$current_dirty_background_bytes
    sudo sysctl -w vm.dirty_bytes=$current_dirty_bytes
}

# Remover linhas vazias duplicadas do arquivo sysctl_conf_file
sed -i '/^$/d' "$sysctl_conf_file"

# Detectar os valores atuais das configurações do sysctl
detect_current_sysctl_settings

# Verificar a quantidade de RAM e ajustar as configurações conforme necessário
adjust_settings_based_on_memory

# Aplicar as configurações do sysctl
apply_sysctl_settings
apply_security_settings

# Função para exibir o menu
show_menu() {
    echo "Menu:"
    echo "1. Aplicar/configurar as configurações do sysctl"
    echo "2. Restaurar configurações anteriores do sysctl"
    echo "0. Sair"
    echo ""
    read -p "Digite o número correspondente à ação desejada: " option
    echo ""

    case $option in
        1)
            adjust_settings_based_on_memory
            apply_sysctl_settings
            apply_security_settings
            echo "Configurações do sysctl aplicadas."
            ;;
        2)
            restore_sysctl_settings
            echo "Configurações do sysctl restauradas."
            ;;
        0)
            exit 0
            ;;
        *)
            echo "Opção inválida. Tente novamente."
            ;;
    esac
}

# Loop do menu interativo
while true; do
    show_menu
done
