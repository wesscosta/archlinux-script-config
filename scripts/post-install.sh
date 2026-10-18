#!/bin/bash
# Pós-instalação do Arch Linux (KDE Plasma / notebook Intel + NVIDIA / Btrfs + Snapper).
# Idempotente: pode ser executado de novo sem duplicar configurações.
# Pressupõe a instalação base feita com o layout de subvolumes descrito no README.
#
# Uso: ./scripts/post-install.sh [categorias...]   (padrão: base kde nvidia; opcional: dev)
#      Ex.: ./scripts/post-install.sh base kde nvidia dev
set -euo pipefail
source "$(dirname "$0")/../lib/comum.sh"
exigir_nao_root
exigir_boot_montado

CATEGORIAS=("$@")
(( $# )) || CATEGORIAS=(base kde nvidia)

info "Arquivos de sistema (pacman.conf, hooks, grub, mkinitcpio, sddm, zram)"
sudo "$REPO_DIR/scripts/instalar-sistema.sh"

info "Mirrors (reflector)"
sudo pacman -S --needed --noconfirm reflector
sudo cp -p /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
sudo reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist

info "Atualizando o sistema"
sudo pacman -Syu

info "Pacotes do repositório (pacotes/: ${CATEGORIAS[*]})"
lista() { grep -hv '^#' "$@" | sed '/^$/d'; }
arquivos=()
for c in "${CATEGORIAS[@]}"; do
    [[ -f $REPO_DIR/pacotes/$c.txt ]] || erro "categoria inexistente: $c (veja pacotes/)"
    arquivos+=("$REPO_DIR/pacotes/$c.txt")
done
mapfile -t pacotes < <(lista "${arquivos[@]}")
sudo pacman -S --needed "${pacotes[@]}"

info "yay"
if ! command -v yay &>/dev/null; then
    tmp=$(mktemp -d)
    git clone https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
    (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
    rm -rf "$tmp"
fi

info "Configurações do usuário (makepkg com !debug, zsh, Konsole, VS Code)"
"$REPO_DIR/scripts/instalar-home.sh"

info "Pacotes do AUR (pacotes/aur.txt)"
mapfile -t aur < <(lista "$REPO_DIR/pacotes/aur.txt" | grep -vx 'yay')
yay -S --needed "${aur[@]}"

info "Oh My Zsh + plugins"
if [[ ! -d $HOME/.oh-my-zsh ]]; then
    # --unattended evita que o instalador abra um zsh novo e interrompa este script
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
for p in zsh-syntax-highlighting zsh-autosuggestions; do
    [[ -d $ZSH_CUSTOM/plugins/$p ]] || git clone "https://github.com/zsh-users/$p" "$ZSH_CUSTOM/plugins/$p"
done
[[ $(getent passwd "$USER" | cut -d: -f7) == */zsh ]] || chsh -s /usr/bin/zsh

info "Serviços"
for s in NetworkManager bluetooth sddm docker grub-btrfsd fstrim.timer \
         snapper-timeline.timer snapper-cleanup.timer \
         nvidia-suspend nvidia-resume nvidia-hibernate; do
    systemctl cat "$s" &>/dev/null && sudo systemctl enable "$s"
done

info "Grupos"
for g in docker libvirt; do
    getent group "$g" >/dev/null && sudo usermod -aG "$g" "$USER"
done

info "Conferindo kernels em /boot"
/usr/local/bin/verificar-kernels-boot

ok "Pós-instalação concluída. Reinicie quando quiser (o script não reinicia sozinho)."
echo "Jogos: ./scripts/setup-gaming.sh   |   Snapper: docs/btrfs-snapper.md"
