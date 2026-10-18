#!/bin/bash
# Move /var/lib/docker de dentro do subvolume @ para um subvolume próprio (@docker),
# para que imagens e build cache não entrem nos snapshots do Snapper.
#
# O diretório antigo fica em /var/lib/docker.antigo até você conferir que está tudo ok.
#
# Uso: sudo ./scripts/docker-subvolume.sh
set -euo pipefail
source "$(dirname "$0")/../lib/comum.sh"
exigir_root

[[ $(findmnt -n -o FSTYPE /) == btrfs ]] || erro "/ não é Btrfs."
findmnt -n /var/lib/docker >/dev/null && erro "/var/lib/docker já é um ponto de montagem. Nada a fazer."
[[ -d /var/lib/docker ]] || erro "/var/lib/docker não existe."
[[ -e /var/lib/docker.antigo ]] && erro "/var/lib/docker.antigo já existe; resolva antes de continuar."

DEV=$(findmnt -n -o SOURCE / | sed 's/\[.*//')
UUID=$(findmnt -n -o UUID /)
OPCOES=$(awk '$2 == "/" && $3 == "btrfs" {print $4}' /etc/fstab | sed 's#subvol=[^,]*#subvol=/@docker#')
[[ $OPCOES == *subvol=/@docker* ]] || erro "não consegui derivar as opções de montagem a partir da linha de / no fstab."

info "Tamanho atual: $(du -sh --one-file-system /var/lib/docker | cut -f1)"
if systemctl is-active -q docker; then
    docker system df
    confirmar "Limpar o build cache antes (docker builder prune -a)?" && docker builder prune -a -f
    confirmar "Remover imagens sem container (docker image prune -a)?" && docker image prune -a -f
    imagens_antes=$(docker image ls -q | sort -u | wc -l)
else
    imagens_antes=""
fi

echo
info "Plano:"
echo "  1. parar docker.socket e docker.service"
echo "  2. criar o subvolume @docker no topo de $DEV e copiar os dados (reflink)"
echo "  3. renomear /var/lib/docker -> /var/lib/docker.antigo"
echo "  4. adicionar ao /etc/fstab (cópia em /etc/fstab.bak-$(date +%Y%m%d)):"
echo "     UUID=$UUID  /var/lib/docker  btrfs  $OPCOES  0 0"
echo "  5. montar e reiniciar o Docker"
confirmar "Prosseguir?" || exit 0

RAIZ=$(mktemp -d)
trap 'umount "$RAIZ" 2>/dev/null; rmdir "$RAIZ"' EXIT
mount -o subvolid=5 "$DEV" "$RAIZ"

if [[ -e $RAIZ/@docker ]]; then
    [[ -z $(ls -A "$RAIZ/@docker") ]] || erro "$RAIZ/@docker já existe e não está vazio."
else
    btrfs subvolume create "$RAIZ/@docker"
fi

info "Parando o Docker"
systemctl stop docker.socket docker.service

info "Copiando dados (reflink: não duplica espaço)"
cp -a --reflink=auto /var/lib/docker/. "$RAIZ/@docker/"

modo=$(stat -c %a /var/lib/docker)
mv /var/lib/docker /var/lib/docker.antigo
mkdir -m "$modo" /var/lib/docker

cp -a /etc/fstab "/etc/fstab.bak-$(date +%Y%m%d)"
printf '\n# Docker fora dos snapshots de @\nUUID=%s\t/var/lib/docker\tbtrfs     \t%s\t0 0\n' "$UUID" "$OPCOES" >> /etc/fstab
systemctl daemon-reload
mount /var/lib/docker
findmnt /var/lib/docker

info "Iniciando o Docker"
systemctl start docker.socket docker.service
docker info --format 'Root: {{.DockerRootDir}}  Driver: {{.Driver}}'
if [[ -n $imagens_antes ]]; then
    imagens_depois=$(docker image ls -q | sort -u | wc -l)
    echo "Imagens antes: $imagens_antes  depois: $imagens_depois"
    [[ $imagens_antes == "$imagens_depois" ]] || aviso "a contagem de imagens mudou; NÃO apague o diretório antigo antes de investigar."
fi

echo
ok "Migração concluída."
echo "Teste seus containers. Quando estiver tudo certo, libere o espaço com:"
echo "  sudo rm -rf /var/lib/docker.antigo"
echo "O espaço só volta de fato quando os snapshots antigos do Snapper que contêm o Docker expirarem ou forem apagados."
