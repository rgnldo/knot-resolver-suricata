#!/bin/bash

# Verificar se o comando 'wget' está disponível
if ! command -v wget >/dev/null 2>&1; then
    echo "O comando 'wget' não está instalado. Por favor, instale-o para continuar."
    exit 1
fi

# Verificar se o comando 'unzip' está disponível
if ! command -v unzip >/dev/null 2>&1; then
    echo "O comando 'unzip' não está instalado. Por favor, instale-o para continuar."
    exit 1
fi

# Verificar se o Zsh está instalado
if ! command -v zsh >/dev/null 2>&1; then
    echo "O Zsh não está instalado. Por favor, instale-o para continuar."
    exit 1
fi

# Baixa o arquivo ZIP
curl -L -O https://github.com/rgnldo/knot-resolver-suricata/raw/master/_zsh.zip

# Descompacta o arquivo ZIP recursivamente no diretório do usuário
unzip -o -q "$HOME" _zsh.zip

# Define o shell padrão do usuário como zsh
chsh -s /usr/bin/zsh "$USER"

# Remove o arquivo ZIP
rm _zsh.zip

echo "Instalação do Zsh concluída com sucesso!"

