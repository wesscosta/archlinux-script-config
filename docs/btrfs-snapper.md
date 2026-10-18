# Btrfs, Snapper e espaço em disco

## Layout

| Subvolume      | Montado em               | Entra no snapshot de `/`? |
|----------------|--------------------------|---------------------------|
| `@`            | `/`                      | é o próprio               |
| `@home`        | `/home`                  | não                       |
| `@.snapshots`  | `/.snapshots`            | não                       |
| `@pkg`         | `/var/cache/pacman/pkg`  | não                       |
| `@log`         | `/var/log`               | não                       |
| `@docker`      | `/var/lib/docker`        | não (após `scripts/docker-subvolume.sh`) |
| (EFI, vfat)    | `/boot`                  | não: fica fora do Btrfs   |

Opções: `compress=zstd:3,ssd,discard=async,space_cache=v2`.

Snapshots: o **Snapper** (config `root`) com `snap-pac` (pre/post a cada transação do pacman) e o
`grub-btrfs` (`grub-btrfsd`), que coloca os snapshots no menu do GRUB. O Timeshift não é usado;
não instale os dois juntos.

## Espaço: `df` não conta a história toda

O Btrfs aloca espaço em *chunks*. O `df` pode mostrar 50% livre enquanto quase todo o disco já está
**alocado**. Sem espaço não alocado, o Btrfs não consegue criar chunks de metadados e dá ENOSPC.

```sh
sudo btrfs filesystem usage -g /     # olhe "Device unallocated": mantenha > 20 GiB
```

## Diagnóstico

```sh
sudo ./scripts/btrfs-espaco.sh
```

Ele mostra o espaço não alocado, snapshots órfãos do Snapper (no disco, mas fora do `snapper list`),
subvolumes do Timeshift, o tamanho de Docker, containerd, libvirt, cache do pacman e journal, e
**imprime** os comandos de limpeza. Não executa nenhum deles.

## Limpeza, em ordem

1. **Docker** (maior consumidor): `docker builder prune -a` e `docker image prune -a`. Depois mova
   para `@docker` com `sudo ./scripts/docker-subvolume.sh`.
2. **Snapshots do Snapper** que você não precisa: `sudo snapper -c root delete <n>` ou um intervalo
   `<a>-<b>`. Os órfãos (que o `snapper list` não mostra) saem com `btrfs subvolume delete`,
   seguindo o comando impresso pelo diagnóstico.
3. **Timeshift**: apague os subvolumes `timeshift-btrfs/...` montando o topo do Btrfs
   (`mount -o subvolid=5`) e depois `sudo pacman -Rns timeshift`.
4. **Rotina**: `./scripts/limpeza.sh` (órfãos, `-debug`, paccache, journal, caches).
5. **Balance**, para devolver chunks pouco usados ao espaço não alocado:
   ```sh
   sudo btrfs balance start -dusage=10 /
   sudo btrfs balance start -dusage=30 /
   ```
   Comece com valores baixos: é rápido e seguro. Valores altos movem muito dado.

Arquivos apagados em `@` só liberam espaço quando **todos** os snapshots que os contêm forem removidos.

## Limites recomendados do Snapper

Em `/etc/snapper/configs/root`:

```
NUMBER_LIMIT="10"
NUMBER_LIMIT_IMPORTANT="5"
TIMELINE_CREATE="yes"
TIMELINE_LIMIT_HOURLY="5"
TIMELINE_LIMIT_DAILY="7"
TIMELINE_LIMIT_WEEKLY="2"
TIMELINE_LIMIT_MONTHLY="1"
TIMELINE_LIMIT_YEARLY="0"
```

E deixe habilitados `snapper-timeline.timer` e `snapper-cleanup.timer`.
