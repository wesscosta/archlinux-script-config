#!/bin/bash
# Diagnóstico de espaço do Btrfs. NÃO altera nada: apenas mostra o estado e
# imprime os comandos sugeridos. O passo a passo da limpeza está em docs/btrfs-snapper.md.
#
# Uso: sudo ./scripts/btrfs-espaco.sh
set -euo pipefail
source "$(dirname "$0")/../lib/comum.sh"
exigir_root

LIMITE_NAO_ALOCADO_GIB=20
sugestoes=()

info "Uso do sistema de arquivos"
btrfs filesystem usage -g / | sed -n '1,12p'

nao_alocado=$(btrfs filesystem usage -b / | awk '/Device unallocated:/ {print $3}')
nao_alocado_gib=$(( nao_alocado / 1024 / 1024 / 1024 ))
if (( nao_alocado_gib < LIMITE_NAO_ALOCADO_GIB )); then
    aviso "Só ${nao_alocado_gib} GiB não alocados (mínimo recomendado: ${LIMITE_NAO_ALOCADO_GIB} GiB)."
    sugestoes+=("btrfs balance start -dusage=10 / && btrfs balance start -dusage=30 /   # devolve chunks de dados pouco usados")
else
    ok "${nao_alocado_gib} GiB não alocados"
fi

echo
info "Subvolumes (caminhos relativos ao topo do Btrfs)"
mapfile -t subvols < <(btrfs subvolume list / | awk '{print $NF}')
printf '  %s\n' "${subvols[@]}" | grep -vE '^  @\.snapshots/[0-9]+/snapshot$' || true
echo "  (+ $(printf '%s\n' "${subvols[@]}" | grep -cE '^@\.snapshots/[0-9]+/snapshot$') snapshots do Snapper)"

echo
info "Snapshots do Snapper órfãos (existem em disco, mas não no 'snapper list')"
mapfile -t listados < <(snapper -c root --csvout list --columns number | tail -n +2)
orfaos=()
for sv in "${subvols[@]}"; do
    [[ $sv =~ ^@\.snapshots/([0-9]+)/snapshot$ ]] || continue
    n=${BASH_REMATCH[1]}
    printf '%s\n' "${listados[@]}" | grep -qx "$n" || orfaos+=("$n")
done
if (( ${#orfaos[@]} )); then
    aviso "Órfãos: ${orfaos[*]}"
    for n in "${orfaos[@]}"; do
        sugestoes+=("btrfs subvolume delete /.snapshots/$n/snapshot && rm -r /.snapshots/$n   # órfão do Snapper")
    done
else
    ok "nenhum"
fi
echo "  Snapper lista $(( ${#listados[@]} - 1 )) snapshots (sem contar o 0 = atual)."

echo
info "Subvolumes do Timeshift"
mapfile -t timeshift < <(printf '%s\n' "${subvols[@]}" | grep -E '^timeshift-btrfs/' || true)
if (( ${#timeshift[@]} )); then
    aviso "${#timeshift[@]} subvolume(s) do Timeshift ainda no disco:"
    printf '  %s\n' "${timeshift[@]}"
    sugestoes+=("mkdir -p /mnt/btrfs-raiz && mount -o subvolid=5 $(findmnt -n -o SOURCE / | sed 's/\[.*//') /mnt/btrfs-raiz")
    for sv in "${timeshift[@]}"; do
        sugestoes+=("btrfs subvolume delete /mnt/btrfs-raiz/$sv   # Timeshift")
    done
    sugestoes+=("umount /mnt/btrfs-raiz")
else
    ok "nenhum"
fi
pacman -Qq timeshift &>/dev/null && sugestoes+=("pacman -Rns timeshift   # Snapper já cobre os snapshots")

echo
info "Maiores consumidores dentro de @"
for d in /var/lib/docker /var/lib/containerd /var/lib/libvirt/images /var/cache/pacman/pkg /var/log/journal; do
    [[ -d $d ]] || continue
    printf '  %8s  %s' "$(du -sh --one-file-system "$d" 2>/dev/null | cut -f1)" "$d"
    findmnt -n "$d" >/dev/null && printf '  (subvolume próprio)'
    echo
done
if ! findmnt -n /var/lib/docker >/dev/null && [[ -d /var/lib/docker ]]; then
    aviso "/var/lib/docker está dentro de @: entra em todo snapshot do Snapper."
    sugestoes+=("./scripts/docker-subvolume.sh   # move o Docker para o subvolume @docker")
fi
if command -v docker &>/dev/null && systemctl is-active -q docker; then
    echo; docker system df
    sugestoes+=("docker builder prune   # cache de build")
    sugestoes+=("docker image prune -a  # imagens sem container")
fi

echo
if (( ${#sugestoes[@]} )); then
    info "Comandos sugeridos (revise antes; nenhum foi executado):"
    printf '  %s\n' "${sugestoes[@]}"
    echo "  Lembre: espaço de arquivos apagados só volta quando os snapshots que os contêm forem removidos."
else
    ok "Nada a sugerir."
fi
