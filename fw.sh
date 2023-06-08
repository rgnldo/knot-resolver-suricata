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
      sudo apt-get install ufw fail2ban curl python3 -y
    elif command -v dnf &>/dev/null; then
      # Fedora
      sudo dnf install ufw fail2ban curl python3 -y
    elif command -v yum &>/dev/null; then
      # CentOS ou RHEL
      sudo yum install ufw fail2ban curl python3 -y
    elif command -v pacman &>/dev/null; then
      # Arch Linux ou compat_
      sudo pacman -Syu ufw fail2ban curl python3 --noconfirm
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

echo "Caso necessário, configurando o Fail2ban"

sed -i -e 's|maxretry = 5|maxretry = 3|' -e "s|^#ignoreip = .*|ignoreip = 127.0.0.1/8 ::1 $intip.0/24 $intip6::1 $ipaddr|" /etc/fail2ban/jail.conf
systemctl enable fail2ban
systemctl start fail2ban
sed -ri "s/^#Port.*|^Port.*/Port $sshport/" /etc/ssh/sshd_config

echo "Adicionando opções de segurança no kernel"
# Proteção na rede local
echo "net.ipv4.conf.all.accept_redirects=0" >> /etc/sysctl.d/99-sysctl.conf
echo "net.ipv4.conf.default.accept_redirects=0" >> /etc/sysctl.d/99-sysctl.conf
echo "net.ipv4.conf.all.secure_redirects=0" >> /etc/sysctl.d/99-sysctl.conf
echo "net.ipv4.conf.default.secure_redirects=0" >> /etc/sysctl.d/99-sysctl.conf

# Ignore ICMP redirects
echo "net.ipv6.conf.all.accept_redirects=0" >> /etc/sysctl.d/99-sysctl.conf
echo "net.ipv6.conf.default.accept_redirects=0" >> /etc/sysctl.d/99-sysctl.conf
echo "net.ipv4.conf.all.send_redirects=0" >> /etc/sysctl.d/99-sysctl.conf
echo "net.ipv4.conf.default.send_redirects=0" >> /etc/sysctl.d/99-sysctl.conf

# Ignore ICMP broadcast requests
echo "net.ipv4.icmp_echo_ignore_broadcasts=1" >> /etc/sysctl.d/99-sysctl.conf

# Disable source packet routing
echo "net.ipv4.conf.all.accept_source_route=0" >> /etc/sysctl.d/99-sysctl.conf
echo "net.ipv6.conf.all.accept_source_route=0" >> /etc/sysctl.d/99-sysctl.conf 
echo "net.ipv4.conf.default.accept_source_route=0" >> /etc/sysctl.d/99-sysctl.conf
echo "net.ipv6.conf.default.accept_source_route=0" >> /etc/sysctl.d/99-sysctl.conf


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

# Block SYN attacks
echo "net.ipv4.tcp_syncookies=1" >> /etc/sysctl.d/99-sysctl.conf
echo "net.ipv4.tcp_max_syn_backlog=2048" >> /etc/sysctl.d/99-sysctl.conf
echo "net.ipv4.tcp_synack_retries=2" >> /etc/sysctl.d/99-sysctl.conf
echo "net.ipv4.tcp_syn_retries=5" >> /etc/sysctl.d/99-sysctl.conf

# Log Martians
echo "net.ipv4.conf.all.log_martians=1" >> /etc/sysctl.d/99-sysctl.conf
echo "net.ipv4.icmp_ignore_bogus_error_responses=1" >> /etc/sysctl.d/99-sysctl.conf

# IP Spoofing protection
echo "net.ipv4.conf.all.rp_filter=1" >> /etc/sysctl.d/99-sysctl.conf
echo "net.ipv4.conf.default.rp_filter=1" >> /etc/sysctl.d/99-sysctl.conf

# Ignore ICMP broadcast requests
echo "net.ipv4.icmp_echo_ignore_broadcasts=1" >> /etc/sysctl.d/99-sysctl.conf

# IP Spoofing protection
echo "net.ipv4.conf.all.rp_filter=1" >> /etc/sysctl.d/99-sysctl.conf
echo "net.ipv4.conf.default.rp_filter=1" >> /etc/sysctl.d/99-sysctl.conf

# Hide kernel pointers
echo "kernel.kptr_restrict=2" >> /etc/sysctl.d/99-sysctl.conf 

# Enable panic on OOM
echo "vm.panic_on_oom=1" >> /etc/sysctl.d/99-sysctl.conf

# Reboot kernel ten seconds after OOM
echo "kernel.panic=10" >> /etc/sysctl.d/99-sysctl.conf



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

# Regra para limitar a taxa de conexões TCP para a chain VIRUSPROT
sudo ufw limit log/tcp from any to any

sudo ufw default deny incoming
sudo ufw default deny forward
sudo ufw default allow outgoing

sed -i '/^COMMIT/i -A ufw-before-output -p icmp -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT' /etc/ufw/before.rules
sed -i '/^COMMIT/i -A ufw-before-output -p icmp -m state --state ESTABLISHED,RELATED -j ACCEPT' /etc/ufw/before.rules
sed -i '/^COMMIT/i -A ufw6-before-output -p icmpv6 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT' /etc/ufw/before6.rules
sed -i '/^COMMIT/i -A ufw6-before-output -p icmpv6 -m state --state ESTABLISHED,RELATED -j ACCEPT' /etc/ufw/before6.rules
sed -i '/^COMMIT/i -A FORWARD -j LOG --log-tcp-options --log-prefix "[UFW FORWARD]"' /etc/ufw/after.rules
sed -i '/^COMMIT/i -A FORWARD -j LOG --log-tcp-options --log-prefix "[UFW FORWARD]"' /etc/ufw/after6.rules
sed -i '/^COMMIT/i -A FORWARD -j LOG --log-tcp-options --log-prefix "[UFW FORWARD]"' /etc/ufw/before.rules
sed -i '/^COMMIT/i -A FORWARD -j LOG --log-tcp-options --log-prefix "[UFW FORWARD]"' /etc/ufw/before6.rules
sed -i '/^COMMIT/i -A INPUT -j LOG --log-tcp-options --log-prefix "[UFW INPUT]"' /etc/ufw/after.rules
sed -i '/^COMMIT/i -A INPUT -j LOG --log-tcp-options --log-prefix "[UFW INPUT]"' /etc/ufw/after6.rules
sed -i '/^COMMIT/i -A INPUT -j LOG --log-tcp-options --log-prefix "[UFW INPUT]"' /etc/ufw/before.rules
sed -i '/^COMMIT/i -A INPUT -j LOG --log-tcp-options --log-prefix "[UFW INPUT]"' /etc/ufw/before6.rules

ufw allow in on lo
ufw allow out on lo
ufw deny in from 127.0.0.0/8
ufw deny in from ::1

ufw allow 53/tcp # DNS
ufw allow 53/udp # DNS
ufw allow 67/udp # DHCP
ufw allow 67/tcp # DHCP
ufw allow 546:547/udp # DHCPv6
ufw allow 137/tcp  
ufw allow 137/udp
ufw allow 138/tcp  
ufw allow 138/udp
ufw allow 445/tcp  
ufw allow 445/udp
ufw allow 631/tcp  
ufw allow 631/udp

echo "Ativando / Reiniciando o ufw"
# Verificar se o UFW está ativo
if sudo ufw status | grep -q "Status: inactive"; then
  echo "O UFW está ativo. Iniciando o UFW..."
  sudo systemctl enable ufw.service
fi
sudo ufw --force enable
sudo ufw reload

echo "Regras de firewall configuradas com sucesso."
