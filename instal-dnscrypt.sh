#!/bin/bash

INSTALL_DIR="/opt/dnscrypt-proxy"
LATEST_URL="https://api.github.com/repos/DNSCrypt/dnscrypt-proxy/releases/latest"
DNSCRYPT_PUBLIC_KEY="RWTk1xXqcTODeYttYMCMLo0YJHaFEHn7a3akqHlb/7QvIQXHVPxKbjB5"
PLATFORM="linux"
CPU_ARCH="x86_64"
alias minisign="$INSTALL_DIR/minisign"

# Função para verificar se o curl está instalado
Verificar_Curl() {
  if ! command -v curl &> /dev/null; then
    echo "[ERROR] curl não está instalado. Por favor, instale o curl e execute o script novamente."
    exit 1
  fi
}

# Função para criar o diretório de instalação se não existir
Criar_Diretorio_Instalacao() {
  if [ ! -d "$INSTALL_DIR" ]; then
    echo "Criando o diretório de instalação $INSTALL_DIR..."
    sudo mkdir -p "$INSTALL_DIR"
    sudo chown "$(whoami)" "$INSTALL_DIR"
    echo "Diretório de instalação criado com sucesso."
  fi
}

# Função para realizar a instalação do DNSCrypt-proxy
Instalar() {
  echo "[INFO] Baixando e instalando o DNSCrypt-proxy..."

  # Verifica se o diretório de instalação existe e o cria, se necessário
  Criar_Diretorio_Instalacao

  # Baixa o arquivo de instalação
  download_url="$(curl -sL "$LATEST_URL" | grep dnscrypt-proxy-${PLATFORM}_${CPU_ARCH}- | grep browser_download_url | head -1 | cut -d \" -f 4)"
  download_file="$INSTALL_DIR/dnscrypt-proxy.tar.gz"
  curl -sL "$download_url" --output "$download_file"

  # Extrai os arquivos
  tar xzf "$download_file" -C "$INSTALL_DIR" --strip-components=1

  # Baixa e configura o arquivo de configuração
  echo "[INFO] Baixando e configurando o arquivo de configuração..."
  curl -sL "https://raw.githubusercontent.com/rgnldo/knot-resolver-suricata/master/dnscrypt-proxy.toml" --output "${INSTALL_DIR}/dnscrypt-proxy.toml"
  
  # Exibe mensagens para configurar a porta e o cache
  Configurar_Porta
  Configurar_Cache

  # Instala o serviço
  echo "[INFO] Instalando o serviço..."
  "$INSTALL_DIR/dnscrypt-proxy" -service install
  systemctl enable dnscrypt-proxy.service
  systemctl start dnscrypt-proxy.service
  systemctl daemon-reload

  # Inicia o servidor para validação
  echo "[INFO] Iniciando o servidor para validação..."
  sudo "$INSTALL_DIR/dnscrypt-proxy"
  echo "[INFO] Por favor, verifique se o servidor está em execução corretamente. Pressione Ctrl+C para parar."
}

# Função para configurar a porta do DNSCrypt-proxy
Configurar_Porta() {
  echo "Por favor, insira o número da porta para o DNSCrypt-proxy (ex: 53):"
  read -r porta
  if [[ "$porta" =~ ^[0-9]+$ ]]; then
    sed -i "s/^listen_addresses.*/listen_addresses = ['127.0.0.1:$porta']/" "${INSTALL_DIR}/dnscrypt-proxy.toml"
    echo "A porta foi configurada para '127.0.0.1:$porta' no arquivo dnscrypt-proxy.toml."
  else
    echo "Por favor, insira um número de porta válido."
  fi
}

# Função para configurar o cache do DNSCrypt-proxy
Configurar_Cache() {
  echo "Deseja habilitar o cache do DNSCrypt-proxy? [s/n]"
  read -r habilitar_cache
  if [[ "$habilitar_cache" == "s" ]]; then
    sed -i "s/^cache = .*/cache = true/" "${INSTALL_DIR}/dnscrypt-proxy.toml"
    echo "O cache foi habilitado no arquivo dnscrypt-proxy.toml."
  else
    sed -i "s/^cache = .*/cache = false/" "${INSTALL_DIR}/dnscrypt-proxy.toml"
    echo "O cache foi desabilitado no arquivo dnscrypt-proxy.toml."
  fi
}

# Função para desinstalar o DNSCrypt-proxy
Desinstalar() {
  echo "Tem certeza de que deseja desinstalar o DNSCrypt-proxy? [s/n]"
  read -r choice
  if [ "$choice" = "s" ]; then
    echo "Desinstalando o DNSCrypt-proxy..."
    rm -rf "$INSTALL_DIR"
    rm -f /etc/systemd/system/dnscrypt-proxy.service
    echo "O DNSCrypt-proxy foi desinstalado."
    Reactivar_systemd_resolved
  else
    echo "Desinstalação abortada."
  fi
}

# Função para desabilitar o systemd-resolved
Desabilitar_systemd_resolved() {
  echo "Desabilitando o systemd-resolved..."
  
  # Faz backup do resolv.conf atual
  sudo cp /etc/resolv.conf /etc/resolv.conf.bak
  
  # Cria um novo resolv.conf com as informações do DNSCrypt
  echo "nameserver ::1" | sudo tee /etc/resolv.conf >/dev/null
  echo "nameserver 127.0.0.1" | sudo tee -a /etc/resolv.conf >/dev/null
  echo "options edns0 trust-ad single-request-reopen" | sudo tee -a /etc/resolv.conf >/dev/null
  
  # Desabilita o systemd-resolved
  systemctl stop systemd-resolved
  systemctl disable systemd-resolved
  systemctl daemon-reload
  echo "O systemd-resolved foi desabilitado e o arquivo /etc/resolv.conf foi atualizado com as configurações do DNSCrypt."
}

# Função para reativar o systemd-resolved
Reativar_systemd_resolved() {
  echo "Reativando o systemd-resolved..."
  mv /etc/resolv.conf.bak /etc/resolv.conf
  systemctl enable systemd-resolved
  systemctl start systemd-resolved
  systemctl daemon-reload
  echo "O systemd-resolved foi reativado e o arquivo /etc/resolv.conf foi restaurado."
}

# Função para sair do script
Sair() {
  echo "Saindo..."
  exit 0
}

# Exibe o menu de opções
Exibir_Menu() {
  echo "Selecione uma opção:"
  echo "1. Instalar o DNSCrypt-proxy"
  echo "2. Desinstalar o DNSCrypt-proxy"
  echo "3. Configurar a porta do DNSCrypt-proxy"
  echo "4. Configurar o cache do DNSCrypt-proxy"
  echo "5. Desabilitar o systemd-resolved"
  echo "6. Reativar o systemd-resolved"
  echo "7. Sair"
}

# Loop principal
while true; do
  Exibir_Menu
  read -r opcao

  case $opcao in
    1) Instalar ;;
    2) Desinstalar ;;
    3) Configurar_Porta ;;
    4) Configurar_Cache ;;
    5) Desabilitar_systemd_resolved ;;
    6) Reativar_systemd_resolved ;;
    7) Sair ;;
    *) echo "Opção inválida. Por favor, selecione uma opção válida." ;;
  esac
done
