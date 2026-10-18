#!/bin/bash
# Reinstala o GRUB na EFI montada em /boot: a entrada principal (EFI/GRUB) e o
# fallback (EFI/BOOT/BOOTX64.EFI), para os dois usarem os módulos da mesma versão.
# Use quando o boot para no prompt do GRUB e só segue com 'exit'.
#
# Uso: sudo ./scripts/reparar-grub.sh
set -euo pipefail
source "$(dirname "$0")/../lib/comum.sh"
exigir_root
exigir_boot_montado

info "Situação atual"
"$REPO_DIR/sistema/usr/local/bin/verificar-grub-efi" 2>&1
efibootmgr | grep -E '^Boot(Current|Order)|GRUB|UEFI OS' || true

confirmar "Reinstalar o GRUB em /boot (entrada GRUB + fallback) e regenerar o grub.cfg?" || exit 0

opcoes=(--target=x86_64-efi --efi-directory=/boot --boot-directory=/boot)
grub-install "${opcoes[@]}" --bootloader-id=GRUB
grub-install "${opcoes[@]}" --removable
grub-mkconfig -o /boot/grub/grub.cfg

# Sobra de um grub-install antigo com --efi-directory=/boot/efi
[[ -d /boot/boot ]] && find /boot/boot -depth -type d -empty -delete

info "Conferindo"
"$REPO_DIR/sistema/usr/local/bin/verificar-grub-efi"
efibootmgr | grep -E '^BootOrder|GRUB'
ok "GRUB reinstalado. A entrada GRUB deve ser a primeira do BootOrder acima."
