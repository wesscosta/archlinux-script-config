# Aliases e funções do Arch. O Oh My Zsh carrega todo *.zsh de $ZSH_CUSTOM automaticamente.

_boot_montado() {
  findmnt -n -M /boot -t vfat >/dev/null && return 0
  print -u2 "ERRO: /boot (EFI) não está montado. Rode: sudo mount /boot"
  return 1
}

# Atualização segura: confere a EFI, atualiza repositórios + AUR e confere os kernels.
# O hook 00-boot-montado.hook também bloqueia o pacman; isto só falha mais cedo.
atualizar() {
  _boot_montado || return 1
  yay -Syu "$@" || return
  [[ -x /usr/local/bin/verificar-kernels-boot ]] && /usr/local/bin/verificar-kernels-boot
}
alias update='atualizar'

alias updateMirrors='sudo cp -p /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bkp && sudo reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist'
alias ll='ls -ltrha'
alias reloadShell='source ~/.zshrc'
alias snaps='sudo snapper -c root list'
