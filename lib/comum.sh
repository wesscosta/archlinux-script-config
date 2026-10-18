# shellcheck shell=bash
# Funções compartilhadas pelos scripts de scripts/. Use com: source "$(dirname "$0")/../lib/comum.sh"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

info()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()    { printf '\033[1;32m ok\033[0m %s\n' "$*"; }
aviso() { printf '\033[1;33m !!\033[0m %s\n' "$*" >&2; }
erro()  { printf '\033[1;31mERRO\033[0m %s\n' "$*" >&2; exit 1; }

# confirmar "pergunta" -> retorna 0 só se a resposta for s/S
confirmar() {
    local resp
    read -r -p "$1 [s/N] " resp
    [[ $resp == [sS] ]]
}

exigir_root()     { [[ $EUID -eq 0 ]] || erro "execute com sudo: sudo $0 $*"; }
exigir_nao_root() { [[ $EUID -ne 0 ]] || erro "não execute como root; o script chama sudo quando precisa."; }

# Aborta se a ESP não estiver montada em /boot (incidente de 18/10/2026).
exigir_boot_montado() {
    findmnt -n -M /boot -t vfat >/dev/null 2>&1 \
        || erro "/boot (EFI) não está montado. Rode 'sudo mount /boot' antes de continuar."
}
