#!/bin/bash
# Copia os arquivos de home/ para o $HOME. Arquivos existentes que diferem
# mostram o diff e pedem confirmação (guarda cópia .bak-AAAAMMDD).
#
# Uso: ./scripts/instalar-home.sh
set -euo pipefail
source "$(dirname "$0")/../lib/comum.sh"
exigir_nao_root

ORIGEM="$REPO_DIR/home"
SUFIXO=".bak-$(date +%Y%m%d)"

while IFS= read -r -d '' -u 3 arq; do
    rel="${arq#"$ORIGEM"/}"
    dest="$HOME/$rel"

    if [[ -e $dest ]] && cmp -s "$arq" "$dest"; then
        ok "~/$rel (igual)"
        continue
    fi

    if [[ -e $dest ]]; then
        info "~/$rel difere do repositório:"
        diff -u "$dest" "$arq" || true
        confirmar "Sobrescrever ~/$rel?" || { aviso "mantido: ~/$rel"; continue; }
        cp -a "$dest" "$dest$SUFIXO"
    fi

    install -D -m 644 "$arq" "$dest"
    ok "instalado: ~/$rel"
done 3< <(find "$ORIGEM" -type f -print0 | sort -z)

info "Painel e widgets do Plasma: veja docs/kde-plasma.md"
