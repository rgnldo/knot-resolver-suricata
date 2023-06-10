#!/bin/bash

echo "Limpar todas as regras e chains nas tabelas filter, nat e mangle"
iptables -F
iptables -t nat -F
iptables -t mangle -F

echo "Excluir todas as chains personalizadas"
iptables -X
iptables -t nat -X
iptables -t mangle -X

echo "Removendo arquivos existentes"
rm /etc/iptables/simple_firewall.rules
rm /etc/iptables/ip6_simple_firewall.rules

echo "Definir a política padrão como ACCEPT para todas as chains"
iptables -P INPUT ACCEPT
iptables -P OUTPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -t nat -P PREROUTING ACCEPT
iptables -t nat -P OUTPUT ACCEPT
iptables -t nat -P POSTROUTING ACCEPT
iptables -t mangle -P PREROUTING ACCEPT
iptables -t mangle -P OUTPUT ACCEPT

echo "Bloqueando vírus"
iptables -N VIRUSPROT
iptables -A VIRUSPROT -m limit --limit 3/minute --limit-burst 10 -j LOG --log-prefix "virusprot: "
iptables -A VIRUSPROT -m conntrack --ctstate NEW -m recent --set --name DEFAULT --mask 255.255.255.255 --rsource 
iptables -A VIRUSPROT -m conntrack --ctstate NEW -m recent --update --seconds 60 --hitcount 10 --name DEFAULT --mask 255.255.255.255 --rsource -j DROP
iptables -A VIRUSPROT -j DROP

echo "SSH lockout"
iptables -N SSHLOCKOUT
iptables -A SSHLOCKOUT -m recent --name sshbf --set -j DROP
iptables -A INPUT -p tcp --dport ssh -m recent --name sshbf --rcheck --seconds 300 --hitcount 4 -j SSHLOCKOUT

echo "Bloqueando todos os portos de destino 0"
iptables -A INPUT -p tcp --destination-port 0 -j DROP
iptables -A INPUT -p udp --destination-port 0 -j DROP

echo "Regra padrão DROP e violações de estado"
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT
iptables -A INPUT -p icmp -j ACCEPT
iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m state --state INVALID -j DROP

echo " Don't log noisy services by default"
iptables -A INPUT -p udp --dport 137 -j DROP
iptables -A INPUT -p udp --dport 138 -j DROP
iptables -A INPUT -p tcp --dport 139 -j DROP
iptables -A INPUT -p tcp --dport 445 -j DROP
iptables -A INPUT -p udp --dport 67 -j DROP
iptables -A INPUT -p udp --dport 68 -j DROP

echo "Permitindo ICMPv6 e CARP"
ip6tables -A INPUT -p icmpv6 -j ACCEPT
ip6tables -A INPUT -m state --state INVALID -j DROP
ip6tables -A INPUT -p vrrp -j ACCEPT

echo "Permitir o serviço NetBIOS (UDP)"
iptables -A INPUT -p udp --dport 137 -j ACCEPT
iptables -A INPUT -p udp --dport 138 -j ACCEPT

echo "Permitir o compartilhamento de arquivos e impressoras do Windows (TCP)"
iptables -A INPUT -p tcp --dport 139 -j ACCEPT
iptables -A INPUT -p tcp --dport 445 -j ACCEPT

echo "Permitir o serviço DHCP (UDP)"
iptables -A INPUT -p udp --dport 67 -j ACCEPT
iptables -A INPUT -p udp --dport 68 -j ACCEPT

echo "Permitir pacotes relacionados ou estabelecidos"
iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

echo "Permitir pacotes destinados ao endereço multicast mDNS"
iptables -A INPUT -p udp -d 224.0.0.251 --dport 5353 -j ACCEPT

echo "Permitir pacotes destinados ao endereço multicast UPnP"
iptables -A INPUT -p udp -d 239.255.255.250 --dport 1900 -j ACCEPT

echo "Permitir pacotes destinados ao endereço local"
iptables -A INPUT -i lo -j ACCEPT

echo "Proteção contra SYN flood"
iptables -A INPUT -p tcp --syn -m connlimit --connlimit-above 10 --connlimit-mask 32 -j DROP

echo "Proteção contra ataques de inundação de ICMP"
iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 1/s --limit-burst 10 -j ACCEPT

echo "Proteção contra ataques de negação de serviço"
iptables -A INPUT -p tcp --dport 80 -m limit --limit 25/s --limit-burst 100 -j ACCEPT

echo "Limitar a taxa de abertura de conexões por segundo"
iptables -A INPUT -p tcp --syn -m conntrack --ctstate NEW -m limit --limit 60/s --limit-burst 20 -j ACCEPT

echo "Restringir a execução de páginas de memória"
iptables -A INPUT -m addrtype --dst-type LOCAL -m limit --limit 1/s --limit-burst 10 -j ACCEPT

echo "Proteção contra estouro de buffer"
iptables -A INPUT -p tcp --tcp-flags ALL NONE -m limit --limit 1/h -j ACCEPT
iptables -A INPUT -p tcp --tcp-flags ALL ALL -m limit --limit 1/h -j ACCEPT

echo "Ocultar kernel pointers"
iptables -A INPUT -m conntrack --ctstate INVALID -j DROP
iptables -A INPUT -p tcp --tcp-flags ALL FIN,URG,PSH -j DROP

echo "Permitir respostas ACK/RTS para acelerar a comunicação"
iptables -A INPUT -p tcp --tcp-flags ACK,FIN FIN -m limit --limit 1/s --limit-burst 10 -j ACCEPT
iptables -A INPUT -p tcp --tcp-flags ACK,PSH PSH -m limit --limit 1/s --limit-burst 10 -j ACCEPT
iptables -A INPUT -p tcp --tcp-flags ACK,URG URG -m limit --limit 1/s --limit-burst 10 -j ACCEPT

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
ip6tables-restore < /etc/iptables/ip6_simple_firewall.rules" | sudo tee "$fw_script_file"

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

