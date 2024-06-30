#!/bin/bash

echo "Limpando todas as regras e chains nas tabelas filter, nat e mangle"
iptables -F
iptables -t nat -F
iptables -t mangle -F

iptables -X
iptables -t nat -X
iptables -t mangle -X

echo "Removendo arquivos existentes"
rm /etc/iptables/test_firewall.rules
rm /etc/iptables/test6_firewall.rules

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

# Regra padrão DROP e violações de estado
echo "Regra padrão DROP e violações de estado"
iptables -A INPUT -p icmp -j ACCEPT
iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A INPUT -m state --state INVALID -j DROP

# Limitar número de conexões TCP por IP
echo "Limitando número de conexões TCP por IP"
iptables -A INPUT -p tcp --syn -m connlimit --connlimit-above 20 --connlimit-mask 32 -j DROP

# Limitar pacotes ICMP Echo-Request
echo "Limitando pacotes ICMP Echo-Request"
iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 5/second --limit-burst 10 -j ACCEPT

# Limitar taxa de novas conexões TCP na porta 80
echo "Limitando taxa de novas conexões TCP na porta 80"
iptables -A INPUT -p tcp --dport 80 -m state --state NEW -m recent --set
iptables -A INPUT -p tcp --dport 80 -m state --state NEW -m recent --update --seconds 60 --hitcount 25 -j DROP

# Proteção contra estouro de buffer
echo "Proteção contra estouro de buffer"
iptables -A INPUT -p tcp --tcp-flags ALL NONE -m limit --limit 1/hour -j ACCEPT
iptables -A INPUT -p tcp --tcp-flags ALL ALL -m limit --limit 1/hour -j ACCEPT

# Bloqueando tráfego destinado à porta 0
echo "Bloqueando tráfego destinado à porta 0"
iptables -A INPUT -p tcp --destination-port 0 -j DROP
iptables -A INPUT -p udp --destination-port 0 -j DROP

##############################
### ATAQUES
##############################
echo "Proteções contra ataques"
# Todas as sessões TCP devem começar com SYN
iptables -A INPUT -p tcp ! --syn -m state --state NEW -s 0.0.0.0/0 -j DROP

# Proteção contra SYN Flood
echo "Proteção contra SYN Flood"
iptables -N syn_flood
iptables -A INPUT -p tcp --syn -j syn_flood
iptables -A syn_flood -m limit --limit 1/s --limit-burst 3 -j RETURN
iptables -A syn_flood -j DROP

# ICMP fragmentado - sinal de ataque DoS
echo "Proteção contra ataques DoS ICMP fragmentados"
iptables -A INPUT --fragment -p ICMP -j DROP

# Limitando as requisições de ping ICMP recebidas
echo "Limitando requisições de ping ICMP"
iptables -A INPUT -p icmp -m limit --limit 1/s --limit-burst 1 -j ACCEPT
iptables -A INPUT -p icmp -j DROP
iptables -A OUTPUT -p icmp -j ACCEPT

# Forçar verificação de pacotes fragmentados
echo "Forçando verificação de pacotes fragmentados"
iptables -A INPUT -f -j DROP

# Pacotes XMAS malformados recebidos
echo "Proteção contra pacotes XMAS malformados"
iptables -A INPUT -p tcp --tcp-flags ALL ALL -j DROP

# Dropar todos os pacotes NULL
echo "Proteção contra pacotes NULL"
iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP

# Pacotes inválidos e suspeitos
echo "Proteção contra pacotes inválidos e suspeitos"
iptables -A INPUT -m state --state INVALID -j DROP

# Proteções contra varreduras furtivas
echo "Proteção contra varreduras furtivas"
# Varredura furtiva 1
iptables -A INPUT -p tcp --tcp-flags ALL NONE -j LOG --log-prefix "FWLOG: Stealth scan (1): "
iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP

# Varredura furtiva 2
iptables -A INPUT -p tcp --tcp-flags ALL ALL -j LOG --log-prefix "FWLOG: Stealth scan (2): "
iptables -A INPUT -p tcp --tcp-flags ALL ALL -j DROP

# Varredura furtiva 3
iptables -A INPUT -p tcp --tcp-flags ALL FIN,URG,PSH -j LOG --log-prefix "FWLOG: Stealth scan (3): "
iptables -A INPUT -p tcp --tcp-flags ALL FIN,URG,PSH -j DROP

# Varredura furtiva 4
iptables -A INPUT -p tcp --tcp-flags ALL SYN,RST,ACK,FIN,URG -j LOG --log-prefix "FWLOG: Stealth scan (4): "
iptables -A INPUT -p tcp --tcp-flags ALL SYN,RST,ACK,FIN,URG -j DROP

# Varredura furtiva 5
iptables -A INPUT -p tcp --tcp-flags SYN,RST SYN,RST -j LOG --log-prefix "FWLOG: Stealth scan (5): "
iptables -A INPUT -p tcp --tcp-flags SYN,RST SYN,RST -j DROP

# Varredura furtiva 6
iptables -A INPUT -p tcp --tcp-flags SYN,FIN SYN,FIN -j LOG --log-prefix "FWLOG: Stealth scan (6): "
iptables -A INPUT -p tcp --tcp-flags SYN,FIN SYN,FIN -j DROP

# Varredura de portas
echo "Proteção contra varredura de portas"
iptables -N port-scan
iptables -A port-scan -p tcp --tcp-flags SYN,ACK,FIN,RST RST -m limit --limit 1/s -j RETURN
iptables -A port-scan -j DROP

# Permitindo ICMPv6 e CARP
echo "Permitindo ICMPv6 e CARP"
ip6tables -A INPUT -p icmpv6 -j ACCEPT
ip6tables -A INPUT -m state --state INVALID -j DROP
ip6tables -A INPUT -p vrrp -j ACCEPT

# Permitindo ssh, www, https e letsencrypt
echo "Permitindo ssh, www, https e letsencrypt"
iptables -A OUTPUT -p tcp -m multiport --dports 22,80,443,54321 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A INPUT -p tcp -m multiport --sports 22,80,443,54321 -m state --state ESTABLISHED -j ACCEPT
iptables -A INPUT -p tcp -m multiport --dports 22,80,443,54321 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -p tcp -m multiport --sports 22,80,443,54321 -m state --state ESTABLISHED -j ACCEPT
iptables -A OUTPUT -p tcp -m multiport --dports 995,3128,992,5555,8080 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A INPUT -p tcp -m multiport --sports 995,3128,992,5555,8080 -m state --state ESTABLISHED -j ACCEPT
iptables -A INPUT -p tcp -m multiport --dports 995,3128,992,5555,8080 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -p tcp -m multiport --sports 995,3128,992,5555,8080 -m state --state ESTABLISHED -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A OUTPUT -p udp -m multiport --dports 53,67,68 -j ACCEPT
iptables -A INPUT -p udp -m multiport --sports 53,67,68 -j ACCEPT
iptables -A OUTPUT -p tcp -m multiport --dports 53,67,68 -j ACCEPT
iptables -A INPUT -p tcp -m multiport --sports 53,67,68 -j ACCEPT

# Configurando marcação para tráfego aceito
echo "Configurando marcação para tráfego aceito"
iptables -t mangle -A OUTPUT -p tcp --dport 53 -j MARK --set-mark 1
iptables -t mangle -A OUTPUT -p udp --dport 53 -j MARK --set-mark 1
iptables -t mangle -A OUTPUT -p tcp --dport 443 -j MARK --set-mark 1

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
iptables-save > /etc/iptables/test_firewall.rules
ip6tables-save > /etc/iptables/test6_firewall.rules

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
