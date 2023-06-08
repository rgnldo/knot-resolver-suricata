#!/bin/bash

# Verificar se o comando 'curl' está disponível
if ! command -v curl >/dev/null 2>&1; then
    echo "O comando 'curl' não está instalado. Por favor, instale-o para continuar."
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

# Baixar o arquivo zip usando o curl
curl -o "$zip_file_path" "$url"

# Verificar se o download foi bem-sucedido
if [ $? -eq 0 ]; then
    echo "O arquivo zip foi baixado com sucesso."
else
    echo "O download do arquivo zip falhou. Verifique a URL ou sua conexão de internet."
    exit 1
fi

# Verificar se o arquivo zip existe
if [ ! -f "$zip_file_path" ]; then
    echo "O arquivo zip não foi encontrado em $zip_file_path."
    exit 1
fi

# Descompactar o arquivo zip na pasta de destino
unzip -q "$zip_file_path" -d "$destination_folder"

# Verificar se a descompactação foi bem-sucedida
if [ $? -eq 0 ]; then
    echo "O arquivo zip foi descompactado com sucesso na pasta $destination_folder."
else
    echo "A descompactação do arquivo zip falhou. Verifique se o arquivo zip é válido."
    exit 1
fi

echo "O download e descompactação do arquivo zip foram concluídos com sucesso."
