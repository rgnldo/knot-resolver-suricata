#!/bin/bash

# Função para criar um arquivo de swap usando dd
create_swap_dd() {
    local size=$1
    echo "Criando arquivo de swap de ${size}MB usando dd..."
    dd if=/dev/zero of=/swapfile bs=1M count="$size" status=progress
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo "Swap criado com dd."
}

# Função para criar um arquivo de swap usando fallocate
create_swap_fallocate() {
    local size=$1
    echo "Criando arquivo de swap de ${size}MB usando fallocate..."
    fallocate -l "${size}M" /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo "Swap criado com fallocate."
}

# Função para configurar swap
configure_swap() {
    local method=$1
    local size=$2
    if [[ ! "$size" =~ ^[0-9]+$ ]]; then
        echo "Tamanho inválido. Deve ser um número inteiro em MB."
        return
    fi
    
    case "$method" in
        dd)
            create_swap_dd "$size"
            ;;
        fallocate)
            create_swap_fallocate "$size"
            ;;
        *)
            echo "Método de criação de swap inválido."
            ;;
    esac
}

# Função para remover o arquivo de swap
remove_swap() {
    echo "Desativando e removendo o arquivo de swap..."
    swapoff /swapfile
    rm -f /swapfile
    echo "Swap removido com sucesso."
}

# Função para adicionar valores ao arquivo /etc/sysctl.conf
add_sysctl_conf() {
    echo "Adicionando configurações ao /etc/sysctl.conf..."
    local sysctl_values=(
        "fs.file-max = 51200"
        "net.core.rmem_max = 67108864"
        "net.core.wmem_max = 67108864"
        "net.core.netdev_max_backlog = 250000"
        "net.core.somaxconn = 4096"
        "net.core.default_qdisc=fq"
        "net.ipv4.tcp_syncookies = 1"
        "net.ipv4.tcp_tw_reuse = 1"
        "net.ipv4.tcp_tw_recycle = 0"
        "net.ipv4.tcp_fin_timeout = 30"
        "net.ipv4.tcp_keepalive_time = 1200"
        "net.ipv4.ip_local_port_range = 10000 65000"
        "net.ipv4.tcp_max_syn_backlog = 8192"
        "net.ipv4.tcp_max_tw_buckets = 5000"
        "net.ipv4.tcp_fastopen = 3"
        "net.ipv4.tcp_mem = 25600 51200 102400"
        "net.ipv4.tcp_rmem = 4096 87380 67108864"
        "net.ipv4.tcp_wmem = 4096 65536 67108864"
        "net.ipv4.tcp_mtu_probing = 1"
        "net.ipv4.tcp_congestion_control = bbr"
    )
    for value in "${sysctl_values[@]}"; do
        if ! grep -qxF "$value" /etc/sysctl.conf; then
            echo "$value" | tee -a /etc/sysctl.conf
        else
            echo "Configuração '$value' já presente em /etc/sysctl.conf"
        fi
    done
}

# Função para remover valores do arquivo /etc/sysctl.conf
remove_sysctl_conf() {
    echo "Removendo configurações do /etc/sysctl.conf..."
    sed -i '/fs.file-max = 51200/d' /etc/sysctl.conf
    sed -i '/net.core.rmem_max = 67108864/d' /etc/sysctl.conf
    sed -i '/net.core.wmem_max = 67108864/d' /etc/sysctl.conf
    sed -i '/net.core.netdev_max_backlog = 250000/d' /etc/sysctl.conf
    sed -i '/net.core.somaxconn = 4096/d' /etc/sysctl.conf
    sed -i '/net.core.default_qdisc=fq/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_syncookies = 1/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_tw_reuse = 1/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_tw_recycle = 0/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_fin_timeout = 30/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_keepalive_time = 1200/d' /etc/sysctl.conf
    sed -i '/net.ipv4.ip_local_port_range = 10000 65000/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_max_syn_backlog = 8192/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_max_tw_buckets = 5000/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_fastopen = 3/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_mem = 25600 51200 102400/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_rmem = 4096 87380 67108864/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_wmem = 4096 65536 67108864/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_mtu_probing = 1/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_congestion_control = bbr/d' /etc/sysctl.conf
}

# Função para adicionar valores ao arquivo /etc/security/limits.conf
add_limits_conf() {
    echo "Adicionando configurações ao /etc/security/limits.conf..."
    local limits_values=(
        "* soft nofile 51200"
        "* hard nofile 51200"
    )
    for value in "${limits_values[@]}"; do
        if ! grep -qxF "$value" /etc/security/limits.conf; then
            echo "$value" | tee -a /etc/security/limits.conf
        else
            echo "Configuração '$value' já presente em /etc/security/limits.conf"
        fi
    done
}

# Função para remover valores do arquivo /etc/security/limits.conf
remove_limits_conf() {
    echo "Removendo configurações do /etc/security/limits.conf..."
    sed -i '/\* soft nofile 51200/d' /etc/security/limits.conf
    sed -i '/\* hard nofile 51200/d' /etc/security/limits.conf
}

# Menu interativo
while true; do
    echo "Selecione uma opção:"
    echo "1) Inserir incremento de conectividade"
    echo "2) Remover incremento de conectividade"
    echo "3) Configurar swap"
    echo "4) Remover swap"
    echo "5) Sair"
    read -p "Opção: " option

    case $option in
        1)
            add_sysctl_conf
            add_limits_conf
            sysctl -p  # Aplicar as mudanças imediatamente
            echo "Configurações aplicadas com sucesso."
            ;;
        2)
            remove_sysctl_conf
            remove_limits_conf
            sysctl -p  # Aplicar as mudanças imediatamente
            echo "Configurações removidas com sucesso."
            ;;
        3)
            echo "Escolha o método para criar o arquivo de swap:"
            echo "1) dd"
            echo "2) fallocate"
            read -p "Método: " method
            if [ "$method" != "1" ] && [ "$method" != "2" ]; then
                echo "Método inválido. Voltando ao menu."
                continue
            fi
            read -p "Digite o tamanho do arquivo de swap em MB: " size
            configure_swap "$([ "$method" = "1" ] && echo "dd" || echo "fallocate")" "$size"
            ;;
        4)
            remove_swap
            ;;
        5)
            echo "Saindo..."
            exit 0
            ;;
        *)
            echo "Opção inválida. Tente novamente."
            ;;
    esac
done
