#!/bin/bash

# Limpar todas as regras e chains nas tabelas filter, nat e mangle
iptables -F
iptables -t nat -F
iptables -t mangle -F

# Excluir todas as chains personalizadas
iptables -X
iptables -t nat -X
iptables -t mangle -X

rm /etc/iptables/simple_firewall.rules
rm /etc/iptables/ip6_simple_firewall.rules

# Definir a política padrão como ACCEPT para todas as chains
iptables -P INPUT ACCEPT
iptables -P OUTPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -t nat -P PREROUTING ACCEPT
iptables -t nat -P OUTPUT ACCEPT
iptables -t nat -P POSTROUTING ACCEPT
iptables -t mangle -P PREROUTING ACCEPT
iptables -t mangle -P OUTPUT ACCEPT

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

# don't log noisy services by default
iptables -A INPUT -p udp --dport 137 -j DROP
iptables -A INPUT -p udp --dport 138 -j DROP
iptables -A INPUT -p tcp --dport 139 -j DROP
iptables -A INPUT -p tcp --dport 445 -j DROP
iptables -A INPUT -p udp --dport 67 -j DROP
iptables -A INPUT -p udp --dport 68 -j DROP

# Permitindo ICMPv6 e CARP
ip6tables -A INPUT -p icmpv6 -j ACCEPT
ip6tables -A INPUT -m state --state INVALID -j DROP
ip6tables -A INPUT -p vrrp -j ACCEPT

# Permitir o serviço NetBIOS (UDP)
iptables -A INPUT -p udp --dport 137 -j ACCEPT
iptables -A INPUT -p udp --dport 138 -j ACCEPT

# Permitir o compartilhamento de arquivos e impressoras do Windows (TCP)
iptables -A INPUT -p tcp --dport 139 -j ACCEPT
iptables -A INPUT -p tcp --dport 445 -j ACCEPT

# Permitir o serviço DHCP (UDP)
iptables -A INPUT -p udp --dport 67 -j ACCEPT
iptables -A INPUT -p udp --dport 68 -j ACCEPT

# Permitir pacotes relacionados ou estabelecidos
iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# Permitir pacotes destinados ao endereço multicast mDNS
iptables -A INPUT -p udp -d 224.0.0.251 --dport 5353 -j ACCEPT

# Permitir pacotes destinados ao endereço multicast UPnP
iptables -A INPUT -p udp -d 239.255.255.250 --dport 1900 -j ACCEPT

# Permitir pacotes destinados ao endereço local
iptables -A INPUT -i lo -j ACCEPT

# Proteção contra SYN flood
iptables -A INPUT -p tcp --syn -m connlimit --connlimit-above 10 --connlimit-mask 32 -j DROP

# Proteção contra ataques de inundação de ICMP
iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 1/s --limit-burst 10 -j ACCEPT

# Proteção contra ataques de negação de serviço
iptables -A INPUT -p tcp --dport 80 -m limit --limit 25/s --limit-burst 100 -j ACCEPT

# Limitar a taxa de abertura de conexões por segundo
iptables -A INPUT -p tcp --syn -m conntrack --ctstate NEW -m limit --limit 60/s --limit-burst 20 -j ACCEPT

# Restringir a execução de páginas de memória
iptables -A INPUT -m addrtype --dst-type LOCAL -m limit --limit 1/s --limit-burst 10 -j ACCEPT

# Proteção contra estouro de buffer
iptables -A INPUT -p tcp --tcp-flags ALL NONE -m limit --limit 1/h -j ACCEPT
iptables -A INPUT -p tcp --tcp-flags ALL ALL -m limit --limit 1/h -j ACCEPT

# Ocultar kernel pointers
iptables -A INPUT -m conntrack --ctstate INVALID -j DROP
iptables -A INPUT -p tcp --tcp-flags ALL FIN,URG,PSH -j DROP

# Permitir respostas ACK/RTS para acelerar a comunicação
iptables -A INPUT -p tcp --tcp-flags ACK,FIN FIN -m limit --limit 1/s --limit-burst 10 -j ACCEPT
iptables -A INPUT -p tcp --tcp-flags ACK,PSH PSH -m limit --limit 1/s --limit-burst 10 -j ACCEPT
iptables -A INPUT -p tcp --tcp-flags ACK,URG URG -m limit --limit 1/s --limit-burst 10 -j ACCEPT

# Salvar regras
iptables-save > /etc/iptables/simple_firewall.rules
ip6tables-save > /etc/iptables/ip6_simple_firewall.rules
iptables-restore < /etc/iptables/simple_firewall.rules
ip6tables-restore < /etc/iptables/ip6_simple_firewall.rules
# Regras de segurança adicionais
