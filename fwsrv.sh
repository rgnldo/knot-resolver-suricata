#!/bin/bash
# Função para mostrar o menu
show_menu() {
	echo "1. Instalar regras de firewall"
	echo "2. Desinstalar regras de firewall"
	echo "3. Sair"
}
# Função para instalar regras de firewall
install_firewall() {
	echo "Instalando regras de firewall..."
	# Obtendo nome da interface principal
	nic=$(ip route get 1.1.1.1 | awk '{print $5}')
	# Verificando se a interface foi obtida
	if [ -z "$nic" ]; then
		echo "Erro: Interface de rede não identificada!"
		exit 1
	fi
	# Perguntar política padrão
	read -p "Defina a política padrão para INPUT (D para DROP, A para ACCEPT): " policy_input
	read -p "Defina a política padrão para OUTPUT (D para DROP, A para ACCEPT): " policy_output
	read -p "Defina a política padrão para FORWARD (D para DROP, A para ACCEPT): " policy_forward
	# Converter políticas para os valores corretos
	if [[ "$policy_input" == "D" ]]; then
		policy_input="DROP"
	elif [[ "$policy_input" == "A" ]]; then
		policy_input="ACCEPT"
	fi
	if [[ "$policy_output" == "D" ]]; then
		policy_output="DROP"
	elif [[ "$policy_output" == "A" ]]; then
		policy_output="ACCEPT"
	fi
	if [[ "$policy_forward" == "D" ]]; then
		policy_forward="DROP"
	elif [[ "$policy_forward" == "A" ]]; then
		policy_forward="ACCEPT"
	fi
	# Verificar se as políticas são válidas
	if [[ "$policy_input" != "DROP" && "$policy_input" != "ACCEPT" ]]; then
		echo "Erro: Política de INPUT inválida!"
		exit 1
	fi
	if [[ "$policy_output" != "DROP" && "$policy_output" != "ACCEPT" ]]; then
		echo "Erro: Política de OUTPUT inválida!"
		exit 1
	fi
	if [[ "$policy_forward" != "DROP" && "$policy_forward" != "ACCEPT" ]]; then
		echo "Erro: Política de FORWARD inválida!"
		exit 1
	fi
	# Perguntar portas TCP a serem abertas
	read -p "Digite as portas TCP que deseja abrir no INPUT (separadas por espaço): " -a open_ports_tcp
	# Perguntar portas UDP a serem abertas
	read -p "Digite as portas UDP que deseja abrir no INPUT (separadas por espaço): " -a open_ports_udp
	# Limpar regras existentes
	echo "Limpando todas as regras e chains nas tabelas filter, nat e mangle"
	iptables -F
	iptables -t nat -F
	iptables -t mangle -F
	iptables -X
	iptables -t nat -X
	iptables -t mangle -X
	echo "Removendo arquivos existentes"
	rm -f /etc/iptables/simple_firewall.rules
	rm -f /etc/iptables/ip6_simple_firewall.rules
	# Definir políticas padrão
	iptables -P INPUT $policy_input
	iptables -P OUTPUT $policy_output
	iptables -P FORWARD $policy_forward
	# Criar cadeias personalizadas
	echo "Criando cadeias personalizadas"
	iptables -N SSHLOCKOUT 2>/dev/null
	iptables -N syn_flood 2>/dev/null
	iptables -N port-scan 2>/dev/null

	# Obtendo interfaces OpenVPN e WireGuard
	openvpn_iface=$(ip a | grep -oP 'tun[0-9]+' | head -n 1)
	wireguard_iface=$(ip a | grep -oP 'wg[0-9]+' | head -n 1)
	# Verificando se as interfaces foram obtidas
	if [ -z "$openvpn_iface" ]; then
		echo "Interface OpenVPN não identificada!"
	fi
	if [ -z "$wireguard_iface" ]; then
		echo "Interface WireGuard não identificada!"
	fi
	# Obtendo IPs das interfaces VPN
	openvpn_ip=$(ip -o -4 addr list $openvpn_iface | awk '{print $4}' | cut -d/ -f1)
	wireguard_ip=$(ip -o -4 addr list $wireguard_iface | awk '{print $4}' | cut -d/ -f1)
	# Obtendo porta e protocolo do OpenVPN
	if [ -f /etc/openvpn/server.conf ]; then
		openvpn_port=$(grep '^port ' /etc/openvpn/server.conf | awk '{print $2}')
		openvpn_proto=$(grep '^proto ' /etc/openvpn/server.conf | awk '{print $2}')
	elif [ -f /etc/openvpn/*.conf ]; then
		openvpn_port=$(grep '^port ' /etc/openvpn/*.conf | awk '{print $2}')
		openvpn_proto=$(grep '^proto ' /etc/openvpn/*.conf | awk '{print $2}')
	else
		echo "Arquivo de configuração do OpenVPN não encontrado!"
	fi
	# Obtendo porta do WireGuard
	if [ -f /etc/wireguard/wg0.conf ]; then
		wireguard_port=$(grep 'ListenPort' /etc/wireguard/wg0.conf | awk '{print $3}')
	else
		echo "Arquivo de configuração do WireGuard não encontrado!"
	fi
	# Exibindo informações obtidas
	echo "Interface OpenVPN: $openvpn_iface"
	echo "IP OpenVPN: $openvpn_ip"
	echo "Porta OpenVPN: $openvpn_port"
	echo "Protocolo OpenVPN: $openvpn_proto"
	echo "Interface WireGuard: $wireguard_iface"
	echo "IP WireGuard: $wireguard_ip"
	echo "Porta WireGuard: $wireguard_port"
	# Adicionando regras de iptables para OpenVPN
	if [ -n "$openvpn_iface" ]; then
		if [ -n "$openvpn_port" ] && [ -n "$openvpn_proto" ]; then
			echo "Adicionando regras de iptables para OpenVPN"
			iptables -A INPUT -p $openvpn_proto --dport $openvpn_port -j ACCEPT
		fi
		echo "Permitindo todo o tráfego da interface OpenVPN"
		iptables -A INPUT -i $openvpn_iface -j ACCEPT
		iptables -A FORWARD -i $openvpn_iface -j ACCEPT
		ip6tables -A FORWARD -i $openvpn_iface -j ACCEPT
	fi
	# Adicionando regras de iptables para WireGuard
	if [ -n "$wireguard_iface" ]; then
		if [ -n "$wireguard_port" ]; then
			echo "Adicionando regras de iptables para WireGuard"
			iptables -A INPUT -p udp --dport $wireguard_port -j ACCEPT
		fi
		echo "Permitindo todo o tráfego da interface WireGuard"
		iptables -A INPUT -i $wireguard_iface -j ACCEPT
		iptables -A FORWARD -i $wireguard_iface -j ACCEPT
		ip6tables -A FORWARD -i $wireguard_iface -j ACCEPT
	fi
	if [ -n "$openvpn_iface" ]; then
		echo "Permitindo comunicação entre $nic e $openvpn_iface"
		iptables -A FORWARD -i $nic -o $openvpn_iface -j ACCEPT
		iptables -A FORWARD -i $openvpn_iface -o $nic -j ACCEPT
		ip6tables -A FORWARD -i $nic -o $openvpn_iface -j ACCEPT
		ip6tables -A FORWARD -i $openvpn_iface -o $nic -j ACCEPT
	fi
	if [ -n "$wireguard_iface" ]; then
		echo "Permitindo comunicação entre $nic e $wireguard_iface"
		iptables -A FORWARD -i $nic -o $wireguard_iface -j ACCEPT
		iptables -A FORWARD -i $wireguard_iface -o $nic -j ACCEPT
		ip6tables -A FORWARD -i $nic -o $wireguard_iface -j ACCEPT
		ip6tables -A FORWARD -i $wireguard_iface -o $nic -j ACCEPT
	fi
	# Configurando mascaramento NAT
	if [ -n "$openvpn_iface" ]; then
		iptables -t nat -A POSTROUTING -o $nic -j MASQUERADE
		ip6tables -t nat -A POSTROUTING -o $nic -j MASQUERADE
	fi
	if [ -n "$wireguard_iface" ]; then
		iptables -t nat -A POSTROUTING -o $nic -j MASQUERADE
		ip6tables -t nat -A POSTROUTING -o $nic -j MASQUERADE
	fi
	# Definir o tamanho máximo dos pacotes pequenos que queremos priorizar
	MAX_SIZE=512
	# Configurar iptables para marcar pacotes pequenos de tráfego web (HTTP/HTTPS) e DNS com TOS 0x10
	# Para pacotes de entrada (HTTP/HTTPS e DNS)
	iptables -t mangle -A PREROUTING -p tcp --dport 80 -m length --length 0:$MAX_SIZE -j TOS --set-tos 0x10
	iptables -t mangle -A PREROUTING -p tcp --dport 443 -m length --length 0:$MAX_SIZE -j TOS --set-tos 0x10
	iptables -t mangle -A PREROUTING -p tcp --dport 53 -m length --length 0:$MAX_SIZE -j TOS --set-tos 0x10
	iptables -t mangle -A PREROUTING -p udp --dport 53 -m length --length 0:$MAX_SIZE -j TOS --set-tos 0x10
	# Para pacotes de saída (HTTP/HTTPS e DNS)
	iptables -t mangle -A OUTPUT -p tcp --dport 80 -m length --length 0:$MAX_SIZE -j TOS --set-tos 0x10
	iptables -t mangle -A OUTPUT -p tcp --dport 443 -m length --length 0:$MAX_SIZE -j TOS --set-tos 0x10
	iptables -t mangle -A OUTPUT -p udp --dport 53 -m length --length 0:$MAX_SIZE -j TOS --set-tos 0x10

	# Adicionar regras à cadeia SSHLOCKOUT
	echo "Configurando regras para a cadeia SSHLOCKOUT"
	iptables -A SSHLOCKOUT -m recent --name sshbf --set -j DROP
	iptables -A INPUT -i $nic -p tcp --dport ssh -m recent --name sshbf --rcheck --seconds 60 --hitcount 4 -j SSHLOCKOUT
	iptables -A INPUT -i $nic -p tcp --dport ssh -m recent --name sshbf --rcheck --seconds 60 --hitcount 4 -j LOG --log-prefix "Tentativa SSH bloqueada: " --log-level 4

	# Proteção contra varredura de portas
	echo "Proteção contra varredura de portas"
	iptables -A port-scan -p tcp --tcp-flags SYN,ACK,FIN,RST RST -m limit --limit 1/s -j RETURN
	iptables -A port-scan -p tcp --tcp-flags SYN,ACK,FIN,RST RST -j DROP
	iptables -A INPUT -j port-scan

	# Proteção contra SYN Flood
	echo "Proteção contra SYN Flood"
	iptables -A INPUT -p tcp --syn -j syn_flood
	iptables -A syn_flood -m limit --limit 1/s --limit-burst 3 -j RETURN
	iptables -A syn_flood -j DROP

	# Configurar NAT
	echo "Configurando NAT moderado"
	iptables -t nat -A POSTROUTING -o $nic -j MASQUERADE

	# Outras regras
	echo "Aplicando outras regras"
	iptables -A INPUT -m state --state INVALID -j DROP
	iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
	iptables -A INPUT -p tcp --syn -m connlimit --connlimit-above 20 --connlimit-mask 32 -j DROP
	iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 5/second --limit-burst 10 -j ACCEPT

	# Proteção contra estouro de buffer
	echo "Proteção contra estouro de buffer"
	iptables -A INPUT -p tcp --tcp-flags ALL NONE -m limit --limit 1/hour -j ACCEPT
	iptables -A INPUT -p tcp --tcp-flags ALL ALL -m limit --limit 1/hour -j ACCEPT

	# Bloqueando tráfego destinado à porta 0
	echo "Bloqueando tráfego destinado à porta 0"
	iptables -A INPUT -p tcp --destination-port 0 -j DROP
	iptables -A INPUT -p udp --destination-port 0 -j DROP

	# Pacotes XMAS malformados recebidos
	echo "Proteção contra pacotes XMAS malformados"
	iptables -A INPUT -p tcp --tcp-flags ALL ALL -j DROP

	# Dropar todos os pacotes NULL
	echo "Proteção contra pacotes NULL"
	iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP

	# Regras padrão para a interface loopback
	echo "Permitindo tráfego na interface loopback"
	#iptables -A INPUT -i lo -j ACCEPT
	iptables -A OUTPUT -o lo -j ACCEPT

	# Abrir portas TCP especificadas pelo usuário
	if [ "${#open_ports_tcp[@]}" -gt 0 ]; then
		for port in "${open_ports_tcp[@]}"; do
			iptables -A INPUT -p tcp --dport "$port" -j ACCEPT
			echo "Porta TCP $port aberta no INPUT."
		done
	fi
	# Abrir portas UDP especificadas pelo usuário
	if [ "${#open_ports_udp[@]}" -gt 0 ]; then
		for port in "${open_ports_udp[@]}"; do
			iptables -A INPUT -p udp --dport "$port" -j ACCEPT
			echo "Porta UDP $port aberta no INPUT."
		done
	fi
	# Ajustando MSS
	echo "Ajustando MSS"
	iptables -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
	iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
	# Salvar regras
	iptables-save >/etc/iptables/simple_firewall.rules
	echo "Gerando a execução..."
	fw_script_file="/usr/local/bin/fw.sh"
	# Verificar se o arquivo já existe
	if [[ -e "$fw_script_file" ]]; then
		echo "O arquivo $fw_script_file já existe. Removendo..."
		sudo rm "$fw_script_file"
	fi
	echo "#!/bin/bash
iptables-restore < /etc/iptables/simple_firewall.rules
" | sudo tee "$fw_script_file"
	sudo chmod +x "$fw_script_file"
	echo "Arquivo $fw_script_file criado com sucesso."
	# Criar o arquivo de serviço para systemd
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
}
# Função para desinstalar regras de firewall
uninstall_firewall() {
	echo "Desinstalando regras de firewall..."
	# Limpar regras existentes
	echo "Limpando todas as regras e chains nas tabelas filter, nat e mangle"
	iptables -F
	iptables -t nat -F
	iptables -t mangle -F
	iptables -X
	iptables -t nat -X
	iptables -t mangle -X
	# Restaurar políticas padrão
	iptables -P INPUT ACCEPT
	iptables -P OUTPUT ACCEPT
	iptables -P FORWARD ACCEPT
	# Remover arquivos de regras salvas
	echo "Removendo arquivos de regras salvas"
	rm -f /etc/iptables/simple_firewall.rules
	echo "Regras de firewall desinstaladas com sucesso."
}
# Loop principal para o menu interativo
while true; do
	show_menu
	read -p "Escolha uma opção: " choice
	case $choice in
	1)
		install_firewall
		;;
	2)
		uninstall_firewall
		;;
	3)
		echo "Saindo..."
		exit 0
		;;
	*)
		echo "Opção inválida, por favor escolha novamente."
		;;
	esac
done
