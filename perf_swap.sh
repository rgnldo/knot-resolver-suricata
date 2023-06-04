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
    echo "vm.overcommit_memory=1" >> /etc/sysctl.d/99-sysctl.conf
    echo "vm.overcommit_ratio=300" >> /etc/sysctl.d/99-sysctl.conf
    echo "vm.swappiness=5" >> /etc/sysctl.d/99-sysctl.conf
    echo "net.ipv4.tcp_syncookies=1" >> /etc/sysctl.d/99-sysctl.conf
    echo "vm.vfs_cache_pressure=10" >> /etc/sysctl.d/99-sysctl.conf
    echo "vm.dirty_background_bytes=4194304" >> /etc/sysctl.d/99-sysctl.conf
    echo "vm.dirty_bytes=4194304" >> /etc/sysctl.d/99-sysctl.conf
    echo "vm.page-cluster=0" >> /etc/sysctl.d/99-sysctl.conf
# Proteção na rede local
    echo "net.ipv4.conf.all.accept_redirects=0" >> /etc/sysctl.d/99-sysctl.conf
    echo "net.ipv4.conf.default.accept_redirects=0" >> /etc/sysctl.d/99-sysctl.conf
    echo "net.ipv4.conf.all.secure_redirects=0" >> /etc/sysctl.d/99-sysctl.conf
    echo "net.ipv4.conf.default.secure_redirects=0" >> /etc/sysctl.d/99-sysctl.conf
    echo "net.ipv6.conf.all.accept_redirects=0" >> /etc/sysctl.d/99-sysctl.conf
    echo "net.ipv6.conf.default.accept_redirects=0" >> /etc/sysctl.d/99-sysctl.conf
    echo "net.ipv4.conf.all.send_redirects=0" >> /etc/sysctl.d/99-sysctl.conf
    echo "net.ipv4.conf.default.send_redirects=0" >> /etc/sysctl.d/99-sysctl.conf
    echo "net.ipv4.conf.default.rp_filter=1" >> /etc/sysctl.d/99-sysctl.conf
    echo "net.ipv4.conf.all.rp_filter=1" >> /etc/sysctl.d/99-sysctl.conf
    echo "net.core.default_qdisc=cake" >> /etc/sysctl.d/99-sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.d/99-sysctl.conf
    echo "net.core.rmem_default=1048576" >> /etc/sysctl.d/99-sysctl.conf
    echo "net.core.rmem_max=16777216" >> /etc/sysctl.d/99-sysctl.conf
    echo "net.core.wmem_default=1048576" >> /etc/sysctl.d/99-sysctl.conf
    echo "net.core.wmem_max=16777216" >> /etc/sysctl.d/99-sysctl.conf
    echo "net.core.optmem_max=65536" >> /etc/sysctl.d/99-sysctl.conf
    echo "net.ipv4.tcp_rmem=4096 1048576 2097152" >> /etc/sysctl.d/99-sysctl.conf
    echo "net.ipv4.tcp_wmem=4096 65536 16777216" >> /etc/sysctl.d/99-sysctl.conf
    echo "net.ipv4.udp_rmem_min=8192" >> /etc/sysctl.d/99-sysctl.conf
    echo "net.ipv4.udp_wmem_min=8192" >> /etc/sysctl.d/99-sysctl.conf
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
