#!/bin/bash
# Jogos no Arch (KDE + NVIDIA). O driver (nvidia-open-dkms) vem de pacotes/nvidia.txt.
# DXVK/VKD3D-Proton não são instalados no sistema: Proton, Lutris e Heroic gerenciam por prefixo.
#
# Uso: ./scripts/setup-gaming.sh
set -euo pipefail
source "$(dirname "$0")/../lib/comum.sh"
exigir_nao_root
exigir_boot_montado

grep -q '^\[multilib\]' /etc/pacman.conf \
    || erro "habilite o [multilib] no /etc/pacman.conf (sistema/etc/pacman.conf já vem com ele)."

info "Pacotes do repositório"
sudo pacman -S --needed \
    steam lutris wine-staging winetricks \
    gamemode lib32-gamemode gamescope mangohud lib32-mangohud \
    nvidia-utils lib32-nvidia-utils vulkan-icd-loader lib32-vulkan-icd-loader vulkan-tools

info "Pacotes do AUR"
yay -S --needed proton-ge-custom-bin heroic-games-launcher-bin

getent group gamemode >/dev/null && sudo usermod -aG gamemode "$USER"

ok "Pronto. Na Steam, use nas opções de lançamento: gamemoderun %command%  (ou: mangohud gamemoderun %command%)"
echo "Gamescope (upscaling FSR): gamescope -W 1920 -H 1080 -w 1280 -h 720 -F fsr -- %command%"
