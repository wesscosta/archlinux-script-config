#!/bin/bash
# Instala os arquivos de sistema/ em /. Para cada arquivo que já existe e difere,
# mostra o diff e pergunta antes de sobrescrever (guarda cópia .bak-AAAAMMDD).
#
# Uso: sudo ./scripts/instalar-sistema.sh
set -euo pipefail
source "$(dirname "$0")/../lib/comum.sh"
exigir_root

ORIGEM="$REPO_DIR/sistema"
SUFIXO=".bak-$(date +%Y%m%d)"

# Arquivos que dependem da máquina: só são instalados com confirmação explícita,
# mesmo que o destino não exista.
SENSIVEIS=(etc/default/grub etc/mkinitcpio.conf etc/pacman.conf)

eh_sensivel() {
    local f
    for f in "${SENSIVEIS[@]}"; do [[ $1 == "$f" ]] && return 0; done
    return 1
}

mudou_grub=0
mudou_mkinitcpio=0

while IFS= read -r -d '' -u 3 arq; do
    rel="${arq#"$ORIGEM"/}"
    dest="/$rel"

    if [[ -e $dest ]] && cmp -s "$arq" "$dest"; then
        ok "$dest (igual)"
        continue
    fi

    if [[ -e $dest ]]; then
        info "$dest difere do repositório:"
        diff -u "$dest" "$arq" || true
        confirmar "Sobrescrever $dest?" || { aviso "mantido: $dest"; continue; }
        cp -a "$dest" "$dest$SUFIXO"
    elif eh_sensivel "$rel"; then
        confirmar "$dest não existe. Instalar a versão do repositório?" || continue
    fi

    modo=644
    [[ $rel == usr/local/bin/* ]] && modo=755
    install -D -m "$modo" "$arq" "$dest"
    ok "instalado: $dest"

    [[ $rel == etc/default/grub ]] && mudou_grub=1
    [[ $rel == etc/mkinitcpio.conf ]] && mudou_mkinitcpio=1
done 3< <(find "$ORIGEM" -type f -print0 | sort -z)

if (( mudou_mkinitcpio )); then
    exigir_boot_montado
    confirmar "mkinitcpio.conf mudou. Regenerar initramfs (mkinitcpio -P)?" && mkinitcpio -P
fi
if (( mudou_grub )); then
    exigir_boot_montado
    confirmar "grub mudou. Regenerar /boot/grub/grub.cfg?" && grub-mkconfig -o /boot/grub/grub.cfg
fi

info "Conferindo kernels e GRUB em /boot:"
/usr/local/bin/verificar-kernels-boot
/usr/local/bin/verificar-grub-efi
