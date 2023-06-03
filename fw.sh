#!/bin/bash

# Limpando todas as regras existentes
iptables -F
iptables -X
iptables -Z

ip6tables -F
ip6tables -X
ip6tables -Z

# Definindo a política padrão como ACCEPT
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

ip6tables -P INPUT ACCEPT
ip6tables -P FORWARD ACCEPT
ip6tables -P OUTPUT ACCEPT

# Detectando interfaces de rede
echo "Interfaces de rede disponíveis:"
ip -o link show | awk -F': ' '{print $2}' | grep -v lo
echo ""
read -p "Digite o nome da interface de rede externa (WAN): " WAN
read -p "Digite o nome da interface de rede interna (LAN): " LAN

# Detectando IPs privados
IPV4_PRIVATE="$(echo '10.0.0.0/8 172.16.0.0/12 192.168.0.0/16' | tr ' ' '\n')"
IPV6_PRIVATE="$(echo 'fc00::/7' | tr ' ' '\n')"

# Bloqueando vírus
iptables -N VIRUSPROT
iptables -A VIRUSPROT -m limit --limit 3/minute --limit-burst 10 -j LOG --log-prefix "virusprot: "
iptables -A VIRUSPROT -m conntrack --ctstate NEW -m recent --set --name DEFAULT --mask 255.255.255.255 --rsource 
iptables -A VIRUSPROT -m conntrack --ctstate NEW -m recent --update --seconds 60 --hitcount 10 --name DEFAULT --mask 255.255.255.255 --rsource -j DROP
iptables -A VIRUSPROT -j DROP

# SSH lockout
iptables -N SSHLOCKOUT
iptables -A SSHLOCKOUT -m recent --name sshbf --set -j DROP
iptables -A INPUT -p tcp --dport ssh -m recent --name sshbf --rcheck --seconds 300 --hitcount 4 -j SSHLOCKOUT

# Bloqueando todos os portos de destino 0
iptables -A INPUT -p tcp --destination-port 0 -j DROP
iptables -A INPUT -p udp --destination-port 0 -j DROP

# Regra padrão DROP e violações de estado
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT
iptables -A INPUT -p icmp -j ACCEPT
iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m state --state INVALID -j DROP

# Permitindo ICMPv6 e CARP
ip6tables -A INPUT -p icmpv6 -j ACCEPT
ip6tables -A INPUT -m state --state INVALID -j DROP
ip6tables -A INPUT -p vrrp -j ACCEPT

# Permitindo Impressoras
iptables -A INPUT -p udp --dport 631 -m conntrack --ctstate NEW -j ACCEPT
iptables -A INPUT -p tcp --dport 631 -m conntrack --ctstate NEW -j ACCEPT

ip6tables -A INPUT -p udp --dport 631 -m conntrack --ctstate NEW -j ACCEPT
ip6tables -A INPUT -p tcp --dport 631 -m conntrack --ctstate NEW -j ACCEPT

# Permitindo Samba
iptables -A INPUT -p tcp --dport 137 -m conntrack --ctstate NEW -j ACCEPT
iptables -A INPUT -p udp --dport 137 -m conntrack --ctstate NEW -j ACCEPT
iptables -A INPUT -p udp --dport 138 -m conntrack --ctstate NEW -j ACCEPT
iptables -A INPUT -p tcp --dport 139 -m conntrack --ctstate NEW -j ACCEPT
iptables -A INPUT -p udp --dport 139 -m conntrack --ctstate NEW -j ACCEPT
iptables -A INPUT -p tcp --dport 445 -m conntrack --ctstate NEW -j ACCEPT
iptables -A INPUT -p udp --dport 445 -m conntrack --ctstate NEW -j ACCEPT

ip6tables -A INPUT -p tcp --dport 137 -m conntrack --ctstate NEW -j ACCEPT
ip6tables -A INPUT -p udp --dport 137 -m conntrack --ctstate NEW -j ACCEPT
ip6tables -A INPUT -p tcp --dport 138 -m conntrack --ctstate NEW -j ACCEPT
ip6tables -A INPUT -p udp --dport 138 -m conntrack --ctstate NEW -j ACCEPT
ip6tables -A INPUT -p tcp --dport 139 -m conntrack --ctstate NEW -j ACCEPT
ip6tables -A INPUT -p udp --dport 139 -m conntrack --ctstate NEW -j ACCEPT
ip6tables -A INPUT -p tcp --dport 445 -m conntrack --ctstate NEW -j ACCEPT
ip6tables -A INPUT -p udp --dport 445 -m conntrack --ctstate NEW -j ACCEPT

# Permitindo SSH
iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -j ACCEPT
ip6tables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -j ACCEPT

# Permitindo Tráfego Multimídia e Multicast
iptables -A INPUT -p udp -m multiport --dports 1024:65535 -m conntrack --ctstate NEW -j ACCEPT
iptables -A INPUT -p igmp -j ACCEPT

ip6tables -A INPUT -p udp -m multiport --dports 1024:65535 -m conntrack --ctstate NEW -j ACCEPT
ip6tables -A INPUT -p icmpv6 -m hl --hl-eq 1 -j ACCEPT

# Salvar regras
iptables-save > /etc/iptables/simple_firewall.rules
ip6tables-save > /etc/iptables/ip6_simple_firewall.rules
iptables-restore < /etc/iptables/simple_firewall.rules
ip6tables-restore < /etc/iptables/ip6_simple_firewall.rules

echo "Reiniciando o ufw"
sudo systemctl restart ufw.service
echo "Regras de firewall configuradas com sucesso."
