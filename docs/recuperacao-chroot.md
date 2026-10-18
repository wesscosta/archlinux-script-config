# Recuperação via chroot

Use quando o sistema não inicia (kernel sumido da EFI, initramfs quebrado, GRUB perdido).
Boot pelo pendrive do Arch e siga a ordem abaixo.

## 1. Montar a raiz (subvolume `@`)

```sh
lsblk -f                                   # confira: nvme0n1p1 = EFI (vfat), nvme0n1p2 = Btrfs
mount -o subvol=@,compress=zstd:3 /dev/nvme0n1p2 /mnt
```

## 2. Entrar no chroot e montar todo o resto

```sh
arch-chroot /mnt
mount -a                                   # monta pelo fstab: /home, /.snapshots, @pkg, @log, /boot (EFI)
```

Sem o `mount -a`, o pacman grava kernels e initramfs no `/boot` **vazio** dentro de `@`,
o cache de pacotes vai para o lugar errado e os logs se perdem. Foi assim que os
kernels sumiram da EFI em 18/10/2026.

Confira antes de seguir:

```sh
findmnt /boot /.snapshots /var/cache/pacman/pkg /var/log
ls /boot                                   # deve mostrar EFI/, grub/, intel-ucode.img
```

O hook `00-boot-montado.hook` aborta qualquer transação do pacman se `/boot` não estiver montado.

## 3. Reinstalar kernels e regenerar initramfs

```sh
verificar-kernels-boot                     # lista o que falta em /boot
pacman -S linux-zen linux-lts linux        # recria vmlinuz e o preset de cada kernel
pacman -S nvidia-open-dkms                 # recompila o módulo para os kernels
mkinitcpio -P
```

Kernels em uso: `linux-zen` (principal), `linux-lts` (fallback, mantenha sempre) e `linux`.

## 4. GRUB

```sh
grub-mkconfig -o /boot/grub/grub.cfg
# Só se a entrada da EFI também sumiu:
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
```

## 5. Sair

```sh
exit
umount -R /mnt
reboot
```

## Alternativa: voltar a um snapshot

Se o problema veio de uma atualização, o `grub-btrfs` lista os snapshots do Snapper no menu do GRUB.
Inicie pelo snapshot `pre` da atualização e, já dentro dele, rode `sudo snapper rollback` e reinicie.
Lembre que o snapshot não contém `/boot` (a EFI fica fora do Btrfs): confira os kernels depois.
