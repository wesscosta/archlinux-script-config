#!/bin/bash
# Backup de pacotes e configurações (não de arquivos pessoais).
# O destino fica FORA do repositório, porque contém dados da máquina.
#
# Uso: ./scripts/backup.sh [diretório-base]   (padrão: ~/backups/arch)
set -euo pipefail
source "$(dirname "$0")/../lib/comum.sh"
exigir_nao_root

BASE="${1:-$HOME/backups/arch}"
DEST="$BASE/backup_arch_$(date +%Y%m%d-%H%M)"
mkdir -p "$DEST"

info "Listas de pacotes"
pacman -Qqen | grep -v -- '-debug$' > "$DEST/pacotes_repo.txt"
pacman -Qqem | grep -v -- '-debug$' > "$DEST/pacotes_aur.txt"
ok "$(wc -l < "$DEST/pacotes_repo.txt") do repositório, $(wc -l < "$DEST/pacotes_aur.txt") do AUR/externos"

info "Serviços habilitados"
systemctl list-unit-files --state=enabled --no-legend | awk '{print $1}' > "$DEST/servicos_sistema.txt"
systemctl --user list-unit-files --state=enabled --no-legend | awk '{print $1}' > "$DEST/servicos_usuario.txt"

info "Configurações do usuário"
cd "$HOME"
itens=(.zshrc .bashrc .gitconfig .config/pacman .config/Code/User/settings.json .config/Code/User/keybindings.json
       .local/share/konsole .config/konsolerc .config/kdeglobals .config/kwinrc .config/kglobalshortcutsrc
       .config/plasma-org.kde.plasma.desktop-appletsrc .config/plasmashellrc .local/share/plasma)
existentes=()
for i in "${itens[@]}"; do [[ -e $i ]] && existentes+=("$i"); done
tar czf "$DEST/config_usuario.tar.gz" "${existentes[@]}"
cd - >/dev/null

info "Configurações do sistema (pede sudo)"
etc=(/etc/pacman.conf /etc/pacman.d/hooks /etc/makepkg.conf /etc/mkinitcpio.conf /etc/mkinitcpio.d
     /etc/default/grub /etc/fstab /etc/sddm.conf.d /etc/snapper/configs /etc/conf.d/snapper
     /etc/systemd/zram-generator.conf /etc/modprobe.d /etc/hostname /etc/locale.conf /etc/vconsole.conf)
existentes=()
for i in "${etc[@]}"; do [[ -e $i ]] && existentes+=("$i"); done
sudo tar czf "$DEST/config_sistema.tar.gz" "${existentes[@]}" 2>/dev/null
sudo chown "$USER:" "$DEST/config_sistema.tar.gz"

ok "Backup em $DEST"
du -sh "$DEST"
