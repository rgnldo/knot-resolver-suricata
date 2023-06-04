#!/bin/bash

# Função para detectar os valores atuais das configurações do sysctl
detect_current_sysctl_settings() {
    current_overcommit_memory=$(sysctl -n vm.overcommit_memory)
    current_overcommit_ratio=$(sysctl -n vm.overcommit_ratio)
    current_swappiness=$(sysctl -n vm.swappiness)
    current_vfs_cache_pressure=$(sysctl -n vm.vfs_cache_pressure)
    current_page_cluster=$(sysctl -n vm.page-cluster)
}

# Função para aplicar as configurações desejadas
apply_sysctl_settings() {
    sudo sysctl vm.overcommit_memory=1
    sudo sysctl vm.overcommit_ratio=300
    sudo sysctl vm.swappiness=5
    sudo sysctl net.ipv4.tcp_syncookies=1
    sudo sysctl vm.vfs_cache_pressure=10
    sudo sysctl vm.dirty_background_bytes=4194304
    sudo sysctl vm.dirty_bytes=4194304
    sudo sysctl vm.page-cluster=0
# Proteção na rede local
    sudo sysctl net.ipv4.conf.all.accept_redirects=0
    sudo sysctl net.ipv4.conf.default.accept_redirects=0
    sudo sysctl net.ipv4.conf.all.secure_redirects=0
    sudo sysctl net.ipv4.conf.default.secure_redirects=0
    sudo sysctl net.ipv6.conf.all.accept_redirects=0
    sudo sysctl net.ipv6.conf.default.accept_redirects=0
    sudo sysctl net.ipv4.conf.all.send_redirects=0
    sudo sysctl net.ipv4.conf.default.send_redirects=0
    sudo sysctl net.ipv4.conf.default.rp_filter=1
    sudo sysctl net.ipv4.conf.all.rp_filter=1
    sudo sysctl net.core.default_qdisc=cake
    sudo sysctl net.ipv4.tcp_congestion_control=bbr
    sudo sysctl net.core.rmem_default=1048576
    sudo sysctl net.core.rmem_max=16777216
    sudo sysctl net.core.wmem_default=1048576
    sudo sysctl net.core.wmem_max=16777216
    sudo sysctl net.core.optmem_max=65536
    sudo sysctl net.ipv4.tcp_rmem = 4096 1048576 2097152
    sudo sysctl net.ipv4.tcp_wmem = 4096 65536 16777216
    sudo sysctl net.ipv4.udp_rmem_min = 8192
    sudo sysctl net.ipv4.udp_wmem_min = 8192
    sudo sysctl -p
}

# Função para restaurar as configurações anteriores
restore_sysctl_settings() {
    sudo sysctl vm.overcommit_memory=$current_overcommit_memory
    sudo sysctl vm.overcommit_ratio=$current_overcommit_ratio
    sudo sysctl vm.swappiness=$current_swappiness
    sudo sysctl vm.vfs_cache_pressure=$current_vfs_cache_pressure
    sudo sysctl vm.page-cluster=$current_page_cluster
}

# Detectar os valores atuais das configurações do sysctl
detect_current_sysctl_settings

# Função para exibir o menu
show_menu() {
    echo "Menu:"
    echo "1. Aplicar configurações do sysctl"
    echo "2. Restaurar configurações anteriores do sysctl"
    echo "0. Sair"
    echo ""
    read -p "Digite o número correspondente à ação desejada: " option
    echo ""

    case $option in
        1)
            apply_sysctl_settings
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
