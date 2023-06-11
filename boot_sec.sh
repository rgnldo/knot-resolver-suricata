#!/bin/bash

echo "Verificar se o pacote sbctl está instalado"
if ! command -v sbctl &> /dev/null; then
    echo "O pacote sbctl não está instalado. Instale-o antes de prosseguir. Consulte a disponibilidade do pacote em sua distribuição"
    exit 1
fi

echo "Exibindo o status do Secure Boot:"
sudo sbctl status

echo "Gerando as chaves de assinatura:"
sudo sbctl create-keys

echo "Registrando as chaves:"
sudo sbctl enroll-keys -m

echo "Verificando as chaves:"
sudo sbctl verify

echo "Assinando o kernel:"

echo "Obter o nome do kernel atual"
kernel=$(ls /boot/vmlinuz-* | sed 's/.*vmlinuz-//')
echo "Assinando o kernel $kernel:"
sudo sbctl sign -s "/boot/vmlinuz-$kernel"

echo "Assinando o arquivo BOOTX64.EFI:"
sudo sbctl sign -s "$(readlink -f /boot/EFI/BOOT/BOOTX64.EFI)"

echo "Assinando o arquivo systemd-bootx64.efi.signed:"
sudo sbctl sign -s -o "$(readlink -f /usr/lib/systemd/boot/efi/systemd-bootx64.efi.signed)" "$(readlink -f /usr/lib/systemd/boot/efi/systemd-bootx64.efi)"

echo "Assinando o arquivo systemd-bootx64.efi:"
sudo sbctl sign -s "$(readlink -f /boot/EFI/systemd/systemd-bootx64.efi)"

echo "Verificando as chaves:"
sudo sbctl verify
