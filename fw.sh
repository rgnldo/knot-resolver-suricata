#!/bin/bash

# Verificar se o UFW está instalado
if ! command -v ufw &>/dev/null; then
  echo "UFW não está instalado. Instalando o UFW..."

  # Verificar o sistema operacional
  if [[ "$(uname)" == "Linux" ]]; then
    # Verificar a distribuição Linux
    if command -v apt-get &>/dev/null; then
      # Ubuntu ou Debian
      sudo apt-get update
      sudo apt-get install ufw -y
    elif command -v dnf &>/dev/null; then
      # Fedora
      sudo dnf install ufw -y
    elif command -v yum &>/dev/null; then
      # CentOS ou RHEL
      sudo yum install ufw -y
    elif command -v pacman &>/dev/null; then
      # Arch Linux ou compat_
      sudo pacman -Syu ufw --noconfirm
    else
      echo "Não foi possível determinar o gerenciador de pacotes adequado para instalar o UFW."
      exit 1
    fi
  else
    echo "O sistema operacional não é suportado. O UFW não pode ser instalado."
    exit 1
  fi
fi

# Verificar se o UFW está ativo e pará-lo
if sudo ufw status | grep -q "Status: active"; then
  echo "O UFW está ativo. Parando o UFW..."
  sudo systemctl stop ufw.service
fi

# Limpa as regras existentes
sudo ufw --force reset

# Define a política padrão para DENY
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Adiciona as regras personalizadas
sudo ufw route limit from any to any app "LOG --log-prefix 'virusprot: '" limit 3/minute burst 10
sudo ufw route allow from any to any app "CONNTRACK NEW recent:set DEFAULT mask 255.255.255.255 rsource"
sudo ufw route deny from any to any app "CONNTRACK NEW recent:update seconds 60 hitcount 10 name DEFAULT mask 255.255.255.255 rsource"
sudo ufw route deny from any to any app "DROP"

sudo ufw route allow from any to any port 22 app "CONNTRACK NEW recent:set SSH rsource"
sudo ufw route deny from any to any port 22 app "CONNTRACK NEW recent:update seconds 300 hitcount 4 name SSH rsource"
sudo ufw route allow from any to any port 22 app "ACCEPT"

sudo ufw route deny proto tcp to any port 0
sudo ufw route deny proto udp to any port 0

sudo ufw default deny incoming
sudo ufw default deny forward
sudo ufw default allow outgoing
sudo ufw route allow icmp
sudo ufw route allow established
sudo ufw route allow in on lo
sudo ufw route deny invalid

sudo ufw route allow from any to any proto ipv6-icmp
sudo ufw route deny invalid
sudo ufw route allow proto vrrp

sudo ufw route allow from any to any port 631 proto udp
sudo ufw route allow from any to any port 631 proto tcp

sudo ufw route allow from any to any port 137 proto tcp
sudo ufw route allow from any to any port 137 proto udp
sudo ufw route allow from any to any port 138 proto tcp
sudo ufw route allow from any to any port 138 proto udp
sudo ufw route allow from any to any port 139 proto tcp
sudo ufw route allow from any to any port 139 proto udp
sudo ufw route allow from any to any port 445 proto tcp
sudo ufw route allow from any to any port 445 proto udp

sudo ufw route allow from any to any port 22 proto tcp
sudo ufw route allow from any to any port 22 proto tcpv6

sudo ufw route allow from any to any proto udp ports 1024:65535
sudo ufw route allow proto igmp

echo "Reiniciando o ufw"
sudo systemctl enable ufw.service
sudo ufw enable
sudo ufw reload

echo "Regras de firewall configuradas com sucesso."
