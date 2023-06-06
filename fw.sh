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

# Editando políticas de acesso
sed -i 's/DEFAULT_FORWARD_POLICY="DROP"/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw

# Define a política padrão para DENY
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Adiciona as regras personalizadas
# Definir o número máximo de tentativas de conexão SSH permitidas antes de bloquear
MAX_ATTEMPTS=4

# Definir o tempo de bloqueio em segundos (aqui, 5 minutos)
BLOCK_TIME=300

# Adicionar regra para permitir conexões SSH
sudo ufw allow ssh

# Adicionar regra para registrar tentativas de conexão SSH
sudo ufw insert 1 deny proto tcp from any to any port 22 comment 'SSH lockout' \
  state NEW recent match --set --name SSH --rsource

# Adicionar regra para bloquear conexões após exceder o número máximo de tentativas
sudo ufw insert 2 deny proto tcp from any to any port 22 comment 'SSH lockout' \
  state NEW recent match --update --seconds $BLOCK_TIME --hitcount $MAX_ATTEMPTS \
  --name SSH --rsource
  
# Criar uma nova chain (cadeia) para VIRUSPROT
sudo ufw route allow in proto tcp from any to any port 0

# Regra para limitar a taxa de conexões TCP para a chain VIRUSPROT
sudo ufw limit log/tcp from any to any

# Bloquear a chain VIRUSPROT

sudo ufw route deny proto tcp to any port 0
sudo ufw route deny proto udp to any port 0

sudo ufw default deny incoming
sudo ufw default deny forward
sudo ufw default allow outgoing

ufw allow 53/tcp # DNS
ufw allow 53/udp # DNS
ufw allow 67/udp # DHCP
ufw allow 67/tcp # DHCP
ufw allow 546:547/udp # DHCPv6
ufw allow 22/tcp

-A ufw-before-input -p icmp --icmp-type destination-unreachable -j ACCEPT
-A ufw-before-input -p icmp --icmp-type source-quench -j ACCEPT
-A ufw-before-input -p icmp --icmp-type time-exceeded -j ACCEPT
-A ufw-before-input -p icmp --icmp-type parameter-problem -j ACCEPT
-A ufw-before-input -p icmp --icmp-type echo-request -j ACCEPT

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

sudo ufw route allow from out to any proto udp ports 1024:65535
sudo ufw allow out proto igmp

echo "Reiniciando o ufw"
#sudo systemctl enable ufw.service
sudo ufw --force enable
sudo ufw reload

echo "Regras de firewall configuradas com sucesso."
