#!/bin/bash

# Função para verificar se o usuário é root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "Este script precisa ser executado como root."
        exit 1
    fi
}

# Função para exibir o menu de tamanhos de swap
choose_swap_size() {
    echo "Digite o tamanho da swap que você deseja criar (ex.: 1G, 512M): "
    read -r swap_size
}

# Função para criar o arquivo de swap
create_swap_file() {
    echo "Criando arquivo de swap..."
    fallocate -l "$swap_size" /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo "Swap de $swap_size criada e ativada."
}

# Função para tornar a swap persistente
make_swap_persistent() {
    echo "Tornando a swap persistente..."
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
    echo "Swap adicionada ao /etc/fstab para persistência após o boot."
}

# Função para ajustar o sysctl.conf
adjust_sysctl() {
    echo "Ajustando parâmetros do sysctl.conf para melhor desempenho de swap..."

    # Verifica a quantidade de memória RAM total
    total_mem=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    vm_swappiness_value=60
    vm_vfs_cache_pressure_value=100

    # Define parâmetros baseados na quantidade de memória
    if [ "$total_mem" -le 2097152 ]; then  # 2GB ou menos
        vm_swappiness_value=10
        vm_vfs_cache_pressure_value=50
    elif [ "$total_mem" -le 4194304 ]; then  # 4GB ou menos
        vm_swappiness_value=20
        vm_vfs_cache_pressure_value=75
    fi

    # Aplica as configurações
    echo "vm.swappiness=$vm_swappiness_value" >> /etc/sysctl.conf
    echo "vm.vfs_cache_pressure=$vm_vfs_cache_pressure_value" >> /etc/sysctl.conf

    # Recarrega as configurações do sysctl
    sysctl -p

    echo "Parâmetros do sysctl ajustados: vm.swappiness=$vm_swappiness_value, vm.vfs_cache_pressure=$vm_vfs_cache_pressure_value"
}

# Função principal do script
main() {
    check_root
    choose_swap_size
    create_swap_file
    make_swap_persistent
    adjust_sysctl
    echo "Configuração de swap concluída com sucesso."
}

# Executa a função principal
main
