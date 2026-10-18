#!/bin/bash
# Configura a organização diária de ~/Downloads com o organize + timer do systemd.
# As regras ficam em home/.config/organize/downloads.yaml (instaladas pelo instalar-home.sh).
#
# Uso:
#   ./scripts/organizar-downloads.sh            simula, pede confirmação e ativa o timer
#   ./scripts/organizar-downloads.sh desativar  desliga o timer
set -euo pipefail
source "$(dirname "$0")/../lib/comum.sh"
exigir_nao_root

REGRAS="$HOME/.config/organize/downloads.yaml"
ORGANIZE="$HOME/.local/bin/organize"
UNIDADE=organizar-downloads.timer

if [[ ${1:-} == desativar ]]; then
    systemctl --user disable --now "$UNIDADE"
    ok "timer desativado"
    exit 0
fi

[[ -f $REGRAS ]] || erro "$REGRAS não existe. Rode antes ./scripts/instalar-home.sh"
[[ -f $HOME/.config/systemd/user/organizar-downloads.service ]] \
    || erro "unidades do systemd ausentes. Rode antes ./scripts/instalar-home.sh"

if [[ ! -x $ORGANIZE ]]; then
    command -v pipx >/dev/null || erro "pipx não encontrado: sudo pacman -S python-pipx"
    confirmar "organize não está instalado. Instalar com pipx (organize-tool)?" || exit 1
    pipx install organize-tool
fi

# As regras usam os nomes de pasta em português; avisa se o XDG da máquina for outro.
for tipo in DOCUMENTS PICTURES VIDEOS MUSIC; do
    dir=$(xdg-user-dir "$tipo" 2>/dev/null || true)
    case $tipo in
        DOCUMENTS) esperado="$HOME/Documentos" ;;
        PICTURES)  esperado="$HOME/Imagens" ;;
        VIDEOS)    esperado="$HOME/Vídeos" ;;
        MUSIC)     esperado="$HOME/Música" ;;
    esac
    [[ -z $dir || $dir == "$esperado" ]] || aviso "XDG $tipo é $dir, mas as regras usam $esperado. Ajuste $REGRAS."
done

"$ORGANIZE" check "$REGRAS"
info "Simulação no seu ~/Downloads atual (nada é alterado):"
"$ORGANIZE" sim "$REGRAS"

confirmar "Ativar a execução diária com essas regras?" || { aviso "nada ativado"; exit 0; }
systemctl --user daemon-reload
systemctl --user enable --now "$UNIDADE"
systemctl --user list-timers "$UNIDADE" --no-pager
ok "Ativo. Logs: journalctl --user -u organizar-downloads.service"
echo "Itens descartados vão para a lixeira do Plasma; nada é apagado de vez."
