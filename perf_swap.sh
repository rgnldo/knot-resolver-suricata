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
    sudo sysctl vm.vfs_cache_pressure=10
    sudo sysctl vm.page-cluster=0
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
