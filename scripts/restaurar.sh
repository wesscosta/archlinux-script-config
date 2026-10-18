#!/bin/bash
# Restaura um backup gerado por scripts/backup.sh. Cada etapa pede confirmação.
# As configurações de /etc NÃO são aplicadas automaticamente (fstab, UUIDs e
# kernels mudam entre instalações): são extraídas para comparação manual.
#
# Uso: ./scripts/restaurar.sh ~/backups/arch/backup_arch_AAAAMMDD-HHMM
set -euo pipefail
source "$(dirname "$0")/../lib/comum.sh"
exigir_nao_root

DIR="${1:-}"
[[ -n $DIR && -d $DIR ]] || erro "informe o diretório do backup. Disponíveis: $(ls -d ~/backups/arch/backup_arch_* 2>/dev/null | tr '\n' ' ')"
DIR=$(realpath "$DIR")
exigir_boot_montado

if [[ -f $DIR/pacotes_repo.txt ]] && confirmar "Instalar pacotes do repositório ($(wc -l < "$DIR/pacotes_repo.txt"))?"; then
    sudo pacman -Sy
    # Ignora pacotes que deixaram de existir nos repositórios, senão a transação inteira falha.
    disponiveis=$(comm -12 <(sort "$DIR/pacotes_repo.txt") <(pacman -Slq | sort -u))
    sumidos=$(comm -23 <(sort "$DIR/pacotes_repo.txt") <(pacman -Slq | sort -u))
    [[ -n $sumidos ]] && aviso "fora dos repositórios (ignorados): $(echo $sumidos)"
    sudo pacman -S --needed $disponiveis
fi

if [[ -f $DIR/pacotes_aur.txt ]] && confirmar "Instalar pacotes do AUR ($(wc -l < "$DIR/pacotes_aur.txt"))?"; then
    command -v yay &>/dev/null || erro "yay não instalado (rode scripts/post-install.sh primeiro)."
    yay -S --needed - < "$DIR/pacotes_aur.txt"
fi

if [[ -f $DIR/config_usuario.tar.gz ]]; then
    tar tzf "$DIR/config_usuario.tar.gz" | sed 's/^/  ~\//' | head -30
    confirmar "Extrair essas configurações no seu home (sobrescreve)?" && tar xzf "$DIR/config_usuario.tar.gz" -C "$HOME"
fi

if [[ -f $DIR/config_sistema.tar.gz ]]; then
    mkdir -p "$DIR/etc-para-comparar"
    tar xzf "$DIR/config_sistema.tar.gz" -C "$DIR/etc-para-comparar"
    info "Configurações de /etc extraídas em $DIR/etc-para-comparar (compare com diff; NUNCA copie o fstab)."
fi

for tipo in sistema usuario; do
    lista="$DIR/servicos_$tipo.txt"
    [[ -f $lista ]] || continue
    escopo=(--system); cmd=(sudo systemctl)
    [[ $tipo == usuario ]] && escopo=(--user) && cmd=(systemctl --user)
    faltando=()
    while read -r u; do
        [[ $u == *@.* ]] && continue   # templates (getty@ etc.) não se habilitam sem instância
        systemctl "${escopo[@]}" cat "$u" &>/dev/null || continue
        systemctl "${escopo[@]}" is-enabled -q "$u" 2>/dev/null || faltando+=("$u")
    done < "$lista"
    if (( ${#faltando[@]} )); then
        echo "Serviços ($tipo) a habilitar: ${faltando[*]}"
        confirmar "Habilitar?" && "${cmd[@]}" enable "${faltando[@]}"
    fi
done

ok "Restauração concluída. Reinicie para aplicar tudo."
