#!/bin/bash

# Verificar se o pacote está instalado
check_package() {
    if [ "$(which "$1" 2>/dev/null)" ]; then
        return 0
    else
        return 1
    fi
}

# Função para instalar um pacote
install_package() {
    if check_package "apt"; then
        sudo apt update
        sudo apt install "$1" -y
    elif check_package "dnf"; then
        sudo dnf install "$1" -y
    elif check_package "pacman"; then
        sudo pacman -Syu --noconfirm "$1"
    else
        echo "Não foi possível determinar o gerenciador de pacotes suportado."
        exit 1
    fi
}

# Função para instalar o pacote Samba
install_samba() {
    if ! check_package "samba"; then
        echo "O pacote Samba não está instalado no sistema."
        read -p "Deseja instalar o pacote Samba? (s/N): " choice
        if [[ $choice == [sS] || $choice == [yY] ]]; then
            install_package "samba"
        else
            echo "A instalação do pacote Samba foi cancelada."
            exit 0
        fi
    fi

    # Verificar se o pacote gvfs-smb está instalado
    if ! check_package "gvfs-smb"; then
        echo "O pacote gvfs-smb não está instalado no sistema."
        read -p "Deseja instalar o pacote gvfs-smb? (s/N): " choice
        if [[ $choice == [sS] || $choice == [yY] ]]; then
            install_package "gvfs-smb"
        else
            echo "A instalação do pacote gvfs-smb foi cancelada."
            exit 0
        fi
    fi
}

# Verificar e instalar o pacote Samba e o pacote gvfs-smb
install_samba

# Baixar o arquivo de configuração smb.conf
sudo wget -O /etc/samba/smb.conf https://raw.githubusercontent.com/rgnldo/knot-resolver-suricata/master/smb.conf

# Verificar se o grupo 'sambashare' existe e adicionar o usuário atual
if ! grep -q "^sambashare:" /etc/group; then
    sudo groupadd sambashare
fi
sudo usermod -aG sambashare "$(whoami)"

echo "Habilitando e iniciando o Samba."
mkdir /home/srv-smb
sudo chmod ugo+rwx /home/srv-smb
sudo smbpasswd -a rgnldo
sudo systemctl enable smb nmb
sudo systemctl start smb nmb

echo "A instalação e configuração do Samba foram concluídas com sucesso."
