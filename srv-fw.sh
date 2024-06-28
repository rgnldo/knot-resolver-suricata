#!/bin/bash

echo "Limpando todas as regras e chains nas tabelas filter, nat e mangle"
iptables -F
iptables -t nat -F
iptables -t mangle -F

iptables -X
iptables -t nat -X
iptables -t mangle -X

echo "Removendo arquivos existentes"
rm /etc/iptables/simple_firewall.rules
rm /etc/iptables/ip6_simple_firewall.rules

# Obtendo nome da interface principal
nic=$(ip route get 1.1.1.1 | awk '{print $5}')

# Verificando se a interface foi obtida
if [ -z "$nic" ]; then
  echo "Erro: Interface de rede não identificada!"
  exit 1
fi

# Obtendo interfaces OpenVPN e WireGuard
openvpn_iface=$(ip a | grep -oP 'tun[0-9]+' | head -n 1)
wireguard_iface=$(ip a | grep -oP 'wg[0-9]+' | head -n 1)

# Verificando se as interfaces foram obtidas
if [ -z "$openvpn_iface" ]; then
  echo "Erro: Interface OpenVPN não identificada!"
fi

if [ -z "$wireguard_iface" ]; then
  echo "Erro: Interface WireGuard não identificada!"
fi

# Obtendo IPs das interfaces VPN
openvpn_ip=$(ip -o -4 addr list $openvpn_iface | awk '{print $4}' | cut -d/ -f1)
wireguard_ip=$(ip -o -4 addr list $wireguard_iface | awk '{print $4}' | cut -d/ -f1)

echo "Definindo a política padrão como DROP para INPUT e FORWARD"
iptables -P INPUT DROP
iptables -P OUTPUT ACCEPT
iptables -P FORWARD DROP

# Criando chain VIRUSPROT
iptables -N VIRUSPROT

# Regras pendentes de ajuste
# 1. Limite de conexões por minuto
iptables -A VIRUSPROT -m limit --limit 3/minute --limit-burst 10 -j LOG --log-prefix "virusprot: Limite excedido - "

# 2. Verificar conexões novas e registrar tentativas
iptables -A VIRUSPROT -m conntrack --ctstate NEW -m recent --set --name VIRUSSCAN --mask 255.255.255.255 --rsource -j LOG --log-prefix "virusprot: Nova conexão de - "

# 3. Atualizar contagem e bloquear por suspeita de vírus
iptables -A VIRUSPROT -m conntrack --ctstate NEW -m recent --update --seconds 60 --hitcount 10 --name VIRUSSCAN --mask 255.255.255.255 --rsource -j DROP

# Regra final: Descartar qualquer pacote na chain VIRUSPROT
iptables -A VIRUSPROT -j DROP

echo "Bloqueio por tentativas de login SSH"
iptables -N SSHLOCKOUT
iptables -A SSHLOCKOUT -m recent --name sshbf --set -j DROP
iptables -A INPUT -i $nic -p tcp --dport ssh -m recent --name sshbf --rcheck --seconds 60 --hitcount 4 -j SSHLOCKOUT
iptables -A INPUT -i $nic -p tcp --dport ssh -m recent --name sshbf --rcheck --seconds 60 --hitcount 4 -j LOG --log-prefix "Tentativa SSH bloqueada: " --log-level 4

# Permitindo todo o tráfego da interface OpenVPN
if [ -n "$openvpn_iface" ]; then
  echo "Permitindo todo o tráfego da interface OpenVPN"
  iptables -A INPUT -i $openvpn_iface -j ACCEPT
  iptables -A FORWARD -i $openvpn_iface -j ACCEPT
fi

# Permitindo todo o tráfego da interface WireGuard
if [ -n "$wireguard_iface" ]; then
  echo "Permitindo todo o tráfego da interface WireGuard"
  iptables -A INPUT -i $wireguard_iface -j ACCEPT
  iptables -A FORWARD -i $wireguard_iface -j ACCEPT
fi

# Permitir comunicação entre NIC e interfaces VPN
if [ -n "$openvpn_iface" ]; then
  echo "Permitindo comunicação entre $nic e $openvpn_iface"
  iptables -A FORWARD -i $nic -o $openvpn_iface -j ACCEPT
  iptables -A FORWARD -i $openvpn_iface -o $nic -j ACCEPT
fi

if [ -n "$wireguard_iface" ]; then
  echo "Permitindo comunicação entre $nic e $wireguard_iface"
  iptables -A FORWARD -i $nic -o $wireguard_iface -j ACCEPT
  iptables -A FORWARD -i $wireguard_iface -o $nic -j ACCEPT
fi

# Permitindo loopback
iptables -A INPUT -i lo -j ACCEPT

# Permitindo tráfego já estabelecido e relacionado
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Limitar número de conexões TCP por IP
iptables -A INPUT -p tcp --syn -m connlimit --connlimit-above 20 --connlimit-mask 32 -j DROP

# Limitar pacotes ICMP Echo-Request
iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 5/second --limit-burst 10 -j ACCEPT

# Limitar taxa de novas conexões TCP na porta 80
iptables -A INPUT -p tcp --dport 80 -m state --state NEW -m recent --set
iptables -A INPUT -p tcp --dport 80 -m state --state NEW -m recent --update --seconds 60 --hitcount 25 -j DROP

# Permitindo loopback
iptables -A INPUT -i lo -j ACCEPT

# Permitindo tráfego já estabelecido e relacionado
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Proteção contra estouro de buffer
echo "Proteção contra estouro de buffer"
iptables -A INPUT -p tcp --tcp-flags ALL NONE -m limit --limit 1/h -j ACCEPT
iptables -A INPUT -p tcp --tcp-flags ALL ALL -m limit --limit 1/h -j ACCEPT

# Proteção contra varreduras de porta
echo "Proteção contra vazamentos"
iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP
iptables -A INPUT -p tcp --tcp-flags ALL ALL -j DROP

# Bloqueando tráfego destinado à porta 0
echo "Bloqueando tráfego destinado à porta 0"
iptables -A INPUT -p tcp --destination-port 0 -j DROP
iptables -A INPUT -p udp --destination-port 0 -j DROP

# Regra padrão DROP e violações de estado
echo "Regra padrão DROP e violações de estado"
iptables -A INPUT -p icmp -j ACCEPT
iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m state --state INVALID -j DROP

# Permitindo ICMPv6 e CARP
echo "Permitindo ICMPv6 e CARP"
ip6tables -A INPUT -p icmpv6 -j ACCEPT
ip6tables -A INPUT -m state --state INVALID -j DROP
ip6tables -A INPUT -p vrrp -j ACCEPT

# Permitindo pacotes destinados ao endereço local
echo "Permitindo pacotes destinados ao endereço local"
iptables -A INPUT -i lo -j ACCEPT

# Permitindo HTTPS e HTTP (TCP)
echo "Permitindo HTTPS e HTTP (TCP)"
iptables -A INPUT -p tcp --dport 443 -j ACCEPT
iptables -A INPUT -p tcp --dport 80 -j ACCEPT

echo "Permitindo UDP 443 (UDP)"
iptables -A INPUT -p udp --dport 443 -j ACCEPT

# Permitindo DNS (TCP e UDP)
echo "Permitindo DNS (TCP e UDP)"
iptables -A INPUT -p tcp --dport 53 -j ACCEPT
iptables -A INPUT -p udp --dport 53 -j ACCEPT

# Permitindo SSH
echo "Permitindo SSH"
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Logging de pacotes suspeitos
iptables -A INPUT -m limit --limit 5/min -j LOG --log-prefix "iptables denied: " --log-level 7

# Configurando marcação para tráfego aceito
echo "Configurando marcação para tráfego aceito"
iptables -t mangle -A OUTPUT -p tcp --dport 53 -j MARK --set-mark 1
iptables -t mangle -A OUTPUT -p udp --dport 53 -j MARK --set-mark 1
iptables -t mangle -A OUTPUT -p tcp --dport 443 -j MARK --set-mark 1
iptables -t mangle -A OUTPUT -p udp --dport 443 -j MARK --set-mark 1
iptables -t mangle -A OUTPUT -p tcp --dport 25 -j MARK --set-mark 3
iptables -t mangle -A OUTPUT -p tcp --dport 110 -j MARK --set-mark 4
iptables -t mangle -A OUTPUT -p tcp --dport 143 -j MARK --set-mark 5

# Configurar QoS com tc
echo "Configurando QoS com tc"

# Limpar regras anteriores do tc
tc qdisc del dev $nic root 2>/dev/null

# Criar qdisc raiz com ajuste r2q
tc qdisc add dev $nic root handle 1: htb default 20 r2q 50

# Criar classes com ajuste de quantum onde necessário
tc class add dev $nic parent 1: classid 1:1 htb rate 1000mbit
tc class add dev $nic parent 1:1 classid 1:10 htb rate 100mbit ceil 1000mbit prio 1 quantum 1500
tc class add dev $nic parent 1:1 classid 1:20 htb rate 500mbit ceil 1000mbit prio 2 quantum 1000

# Adicionar filtros para pacotes marcados com iptables
tc filter add dev $nic parent 1:0 protocol ip handle 1 fw flowid 1:10
tc filter add dev $nic parent 1:0 protocol ip handle 2 fw flowid 1:20
echo "QoS configurado com sucesso"

# Salvar regras
iptables-save > /etc/iptables/simple_firewall.rules
ip6tables-save > /etc/iptables/ip6_simple_firewall.rules

echo "Gerando a execuç."
fw_script_file="/usr/local/bin/fw.sh"

# Verificar se o arquivo já existe
if [[ -e "$fw_script_file" ]]; then
    echo "O arquivo $fw_script_file já existe. Removendo..."
    sudo rm "$fw_script_file"
fi

# Criar o arquivo executável
echo "#!/bin/bash

iptables-restore < /etc/iptables/simple_firewall.rules
ip6tables-restore < /etc/iptables/ip6_simple_firewall.rules

# Reaplicar configurações de QoS com tc após reinício
tc qdisc del dev $nic root 2>/dev/null
tc qdisc add dev $nic root handle 1: htb default 20 r2q 50
tc class add dev $nic parent 1: classid 1:1 htb rate 1000mbit
tc class add dev $nic parent 1:1 classid 1:10 htb rate 100mbit ceil 1000mbit prio 1 quantum 1500
tc class add dev $nic parent 1:1 classid 1:20 htb rate 500mbit ceil 1000mbit prio 2 quantum 1000
tc filter add dev $nic parent 1:0 protocol ip handle 1 fw flowid 1:10
tc filter add dev $nic parent 1:0 protocol ip handle 2 fw flowid 1:20
" | sudo tee "$fw_script_file"

sudo chmod +x "$fw_script_file"

echo "Arquivo $fw_script_file criado com sucesso."

# Script para criar o arquivo de serviço /etc/systemd/system/fw.service
fw_service_file="/etc/systemd/system/fw.service"

# Verificar se o arquivo de serviço já existe
if [[ -e "$fw_service_file" ]]; then
    echo "O arquivo $fw_service_file já existe. Removendo..."
    sudo rm "$fw_service_file"
fi

# Criar o arquivo de serviço
echo "[Unit]
Description=Firewall

[Service]
ExecStart=/usr/local/bin/fw.sh

[Install]
WantedBy=multi-user.target" | sudo tee "$fw_service_file"

echo "Arquivo $fw_service_file criado com sucesso."

# Habilitar e iniciar o serviço
sudo systemctl enable fw.service
sudo systemctl start fw.service

echo "Serviço fw.service habilitado e iniciado com sucesso."
