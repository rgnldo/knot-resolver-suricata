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

# URL do arquivo zip
url="https://github.com/rgnldo/knot-resolver-suricata/raw/master/_zsh.zip"

# Pasta de destino para descompactar o arquivo
destination_folder="$HOME"

# Nome do arquivo zip
zip_file_name="_zsh.zip"

# Caminho completo do arquivo zip
zip_file_path="$destination_folder/$zip_file_name"

# Baixar o arquivo zip usando o wget e descompactar no diretório de destino
wget "$url" -O "$zip_file_path" && unzip -q "$zip_file_path" -d "$destination_folder"

# Verificar se o download e a descompactação foram bem-sucedidos
if [ $? -eq 0 ]; then
    echo "O arquivo zip foi baixado e descompactado com sucesso na pasta $destination_folder."
else
    echo "O download ou descompactação do arquivo zip falhou. Verifique a URL ou sua conexão de internet."
    exit 1
fi

echo "O download e descompactação do arquivo zip foram concluídos com sucesso."
