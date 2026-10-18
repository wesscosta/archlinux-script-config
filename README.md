# archlinux-script-config

Configuração otimizada de Arch Linux com KDE Plasma, baseada na minha experiência de uso diário
num notebook Intel + NVIDIA. Use como ponto de partida: listas de pacotes curadas, arquivos de
configuração comentados, scripts de pós-instalação e manutenção, e runbooks para quando algo quebra.

Testado na configuração abaixo; em hardware diferente, revise `pacotes/nvidia.txt` e
`sistema/etc/default/grub` antes de usar.

| Item          | Configuração                                                       |
|---------------|--------------------------------------------------------------------|
| Testado em    | ASUS TUF F15 (Intel, RTX 4050, NVIDIA PRIME)                       |
| Desktop       | KDE Plasma 6 (Wayland) + SDDM com tema Breeze                      |
| Kernels       | `linux-zen` (principal), `linux-lts` (fallback), `linux`           |
| GPU           | `nvidia-open-dkms`, `nvidia-prime`                                 |
| Disco         | Btrfs (`@`, `@home`, `@.snapshots`, `@pkg`, `@log`, `@docker`) + EFI em `/boot` |
| Boot          | GRUB + `grub-btrfs`                                                |
| Snapshots     | Snapper + `snap-pac`                                               |
| Shell         | zsh + Oh My Zsh                                                    |
| AUR           | yay                                                                |

## Estrutura

```
pacotes/          listas curadas por categoria: base, kde, nvidia, dev e aur
sistema/          arquivos instalados em / (espelha o caminho real)
  etc/pacman.d/hooks/   00-boot-montado.hook, zz-verificar-kernels.hook, zz-verificar-grub.hook
  usr/local/bin/        checar-boot-montado, verificar-kernels-boot, verificar-grub-efi
  etc/…                 pacman.conf, mkinitcpio.conf, default/grub, sddm.conf.d, zram
home/             arquivos instalados em ~ (zsh, makepkg.conf, Konsole, VS Code)
scripts/          post-install, instalar-*, coletar, backup/restaurar, limpeza, btrfs-espaco, docker-subvolume, reparar-grub, setup-gaming
lib/comum.sh      funções compartilhadas (confirmação, checagem de /boot)
docs/             runbooks e registro de incidentes
wallpapers/
```

## Uso

### Instalação nova

Depois do `pacstrap` + GRUB, com o layout de subvolumes acima e `/boot` sendo a EFI:

```sh
git clone https://github.com/wesscosta/archlinux-script-config.git
cd archlinux-script-config
./scripts/post-install.sh       # base kde nvidia (padrão); acrescente 'dev' para desenvolvimento
./scripts/post-install.sh base kde nvidia dev
./scripts/setup-gaming.sh       # opcional
```

### Aplicar só as configurações

```sh
sudo ./scripts/instalar-sistema.sh   # sistema/ -> /    (mostra diff e pergunta antes de sobrescrever)
./scripts/instalar-home.sh           # home/    -> ~
```

### Trazer mudanças da máquina para o repositório

```sh
./scripts/coletar.sh && git diff   # atualiza os arquivos versionados e lista pacotes fora das listas
```

As listas de `pacotes/` são recomendações, não uma cópia de tudo que está instalado: inclua só o que
faz sentido para quem usa um setup parecido.

### Manutenção

| Comando                              | O que faz                                                    |
|--------------------------------------|--------------------------------------------------------------|
| `update` (função `atualizar` do zsh) | confere `/boot`, `yay -Syu`, confere kernels                 |
| `./scripts/limpeza.sh`               | órfãos, `-debug`, paccache, journal, caches (pede confirmação) |
| `sudo ./scripts/btrfs-espaco.sh`     | diagnóstico de espaço e snapshots (só leitura)               |
| `sudo ./scripts/reparar-grub.sh`     | reinstala o GRUB na EFI (boot parando no prompt do GRUB)     |
| `./scripts/backup.sh`                | pacotes + configs em `~/backups/arch` (fora do repo)         |
| `./scripts/restaurar.sh <dir>`       | restaura um backup                                           |

## Proteções

- **EFI desmontada:** o hook `00-boot-montado.hook` aborta qualquer transação do pacman se `/boot`
  não estiver montado. Depois de mexer em kernels, o `zz-verificar-kernels.hook` avisa se algum
  ficou sem vmlinuz, initramfs ou preset.
- **GRUB fora da EFI:** o `zz-verificar-grub.hook` avisa se algum GRUB instalado na EFI procura seus
  arquivos dentro do Btrfs, o que faz o boot parar no prompt do GRUB.
- **Pacotes `-debug`:** `~/.config/pacman/makepkg.conf` com `!debug`.
- **Tela de login:** SDDM só com o Breeze ([docs/kde-plasma.md](docs/kde-plasma.md)).
- **Snapshots enxutos:** Docker em `@docker`, fora dos snapshots de `/`.

## Documentação

- [Recuperação via chroot](docs/recuperacao-chroot.md)
- [Btrfs, Snapper e espaço em disco](docs/btrfs-snapper.md)
- [KDE Plasma e SDDM](docs/kde-plasma.md)
- [Incidente de 18/10/2026](docs/incidentes/2026-10-18.md)

## Licença

MIT. Veja [LICENSE](LICENSE).
