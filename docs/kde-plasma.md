# KDE Plasma 6 (Wayland) e SDDM

## SDDM

O tema do SDDM fica no **Breeze**, que vem com o Plasma e acompanha as atualizações.
Temas de terceiros quebram com novas versões do Plasma/Qt e podem deixar o sistema sem tela de
login (incidente de 18/10/2026).

Arquivos versionados em `sistema/etc/sddm.conf.d/`:

- `kde_settings.conf`: gerado pelas Configurações do Sistema (Tela de login). `Current=breeze`.
- `10-default.conf`: `DisplayServer=x11`. Só o **greeter** do SDDM roda em X11; a sessão do
  Plasma continua em Wayland. É a opção mais estável com NVIDIA. Para testar o greeter em Wayland,
  troque para `DisplayServer=wayland`.

Se a tela de login quebrar, use um TTY (Ctrl+Alt+F3):

```sh
sudo sed -i 's/^Current=.*/Current=breeze/' /etc/sddm.conf.d/kde_settings.conf
sudo systemctl restart sddm
```

## Widgets do painel

O layout do painel não é versionado: ele guarda caminhos e arquivos da área de trabalho de cada
máquina. Estes são os widgets de terceiros que uso, instaláveis pela loja (botão direito no painel →
Adicionar widgets → Obter novos):

| Plugin                           | Widget                |
|----------------------------------|-----------------------|
| `AndromedaLauncher`              | Andromeda Launcher    |
| `KdeControlStation`              | KDE Control Station   |
| `luisbocanegra.panel.colorizer`  | Panel Colorizer       |
| `com.github.prayag2.modernclock` | Modern Clock          |
| `org.kde.olib.thermalmonitor`    | Thermal Monitor       |

Assim como o tema do SDDM, esses widgets podem quebrar a cada versão do Plasma. Se o painel
sumir depois de uma atualização, remova o widget problemático ou volte o painel ao padrão.

## Konsole

Perfil e esquema Dracula em `home/.local/share/konsole/`. A fonte `MesloLGS NF` é do pacote
`ttf-meslo-nerd`.
