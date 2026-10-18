#!/bin/bash
# Limpeza de rotina. Cada passo mostra o que vai fazer e pede confirmação.
# Para espaço no Btrfs (snapshots, Docker, balance) use scripts/btrfs-espaco.sh.
#
# Uso: ./scripts/limpeza.sh
set -euo pipefail
source "$(dirname "$0")/../lib/comum.sh"
exigir_nao_root

info "Pacotes órfãos"
if orfaos=$(pacman -Qdtq); then
    echo "$orfaos"
    confirmar "Remover esses pacotes?" && sudo pacman -Rns $orfaos
else
    ok "nenhum"
fi

info "Pacotes *-debug (gerados por makepkg sem !debug)"
if debug=$(pacman -Qq | grep -- '-debug$'); then
    echo "$debug"
    confirmar "Remover esses pacotes?" && sudo pacman -Rns $debug
else
    ok "nenhum"
fi

info "Cache do pacman: $(du -sh /var/cache/pacman/pkg | cut -f1)"
if command -v paccache &>/dev/null; then
    paccache -dk2 | tail -1
    paccache -duk0 | tail -1
    confirmar "Manter só 2 versões por pacote e apagar as de pacotes desinstalados?" \
        && sudo paccache -rk2 && sudo paccache -ruk0
else
    aviso "paccache não encontrado (instale pacman-contrib)."
fi

if command -v yay &>/dev/null; then
    info "Cache do yay: $(du -sh ~/.cache/yay 2>/dev/null | cut -f1)"
    confirmar "Limpar builds antigas do yay (yay -Sc --aur)?" && yay -Sc --aur
fi

info "Journal: $(journalctl --disk-usage | grep -oE '[0-9.]+[KMGT]')"
confirmar "Reduzir o journal para 200M?" && sudo journalctl --vacuum-size=200M

if command -v flatpak &>/dev/null; then
    info "Runtimes Flatpak sem uso"
    confirmar "Remover (flatpak uninstall --unused)?" && flatpak uninstall --unused
fi

info "~/.cache: $(du -sh ~/.cache 2>/dev/null | cut -f1)"
du -sh ~/.cache/* 2>/dev/null | sort -rh | head -10
confirmar "Apagar TODO o ~/.cache? (feche navegadores e IDEs antes)" && rm -rf ~/.cache/*

ok "Limpeza concluída. Para snapshots e Docker: sudo ./scripts/btrfs-espaco.sh"
