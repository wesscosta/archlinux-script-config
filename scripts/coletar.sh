#!/bin/bash
# Caminho inverso de instalar-*.sh: copia do sistema para o repositório os
# arquivos que já são versionados e atualiza as listas de pacotes.
# Revise com 'git diff' antes de commitar.
#
# Uso: ./scripts/coletar.sh
set -euo pipefail
source "$(dirname "$0")/../lib/comum.sh"
exigir_nao_root

coletar() {  # coletar <raiz do sistema> <diretório no repo>
    local raiz=$1 base=$2 arq rel
    while IFS= read -r -d '' arq; do
        rel="${arq#"$base"/}"
        if [[ -r $raiz/$rel ]]; then
            cp "$raiz/$rel" "$arq"
        else
            aviso "sem leitura (ou inexistente): $raiz/$rel"
        fi
    done < <(find "$base" -type f -print0)
}

info "Arquivos de sistema/"
coletar "" "$REPO_DIR/sistema"

info "Arquivos de home/"
coletar "$HOME" "$REPO_DIR/home"

# As listas de pacotes são curadas (recomendações), não um dump da máquina: não são sobrescritas.
info "Pacotes instalados e removidos que não estão em pacotes/*.txt (avalie se vale recomendar)"
comm -13 <(grep -hv '^#' "$REPO_DIR"/pacotes/*.txt | sort -u) <(pacman -Qqe | grep -v -- '-debug$' | sort) \
    | column -c "${COLUMNS:-100}"

ok "Coleta concluída. Confira com: git -C '$REPO_DIR' diff"
aviso "O settings.json do VS Code volta com caminhos da máquina (yaml.schemas); limpe antes de commitar."
