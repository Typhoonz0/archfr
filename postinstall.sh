#!/usr/bin/bash
# Post install script to make the system useful
essentialpkgs=(git firefox ghostty neovim lf)
suggestedpkgs=(libreoffice-still btop fastfetch tmux cmatrix lolcat discord gparted nautilus firefox swaybg waybar blueberry gnome-shell-extensions)
finalchoice=(gnome hyprland)
dechoice=3
real_user="${SUDO_USER:-$(logname)}"
export HOME="/home/$real_user"
minimal() {
    echo -ne "
-------------------------------------------------------------------------
                        Desktop Enviroment
-------------------------------------------------------------------------
0) Install my own later (skip)
1) Gnome
2) Hyprland
3) Gnome + Hyprland (default)
"
    read -rp "Choice: " dechoice; dechoice=${dechoice:-3}
    case "$dechoice" in
        1) finalchoice=(gnome) ;;
        2) finalchoice=(hyprland) ;;
        3) finalchoice=(gnome hyprland) ;;
        *) finalchoice=(none) ;;
    esac
    pacman -S --noconfirm "${essentialpkgs[@]}" || true
    [[ "$finalchoice" != "none" ]] && pacman -S --noconfirm "${finalchoice[@]}" || true
}

default() {
    essentialpkgs=(git firefox ghostty neovim lf)
    suggestedpkgs=(libreoffice-still btop steam fastfetch tmux cmatrix lolcat discord gparted nautilus firefox swaybg waybar blueberry gnome-shell-extensions)
    declare -A map=( [fastfetch]=fastfetch [ghostty]=ghostty [hypr]=hyprland [nvim]=neovim [rofi]=rofi [tmux]=tmux [waybar]=waybar [zsh]=zsh )

    pacman -Sy --noconfirm
    pacman -S "${essentialpkgs[@]}" 
    pacman -S "${suggestedpkgs[@]}"
    pacman -S --noconfirm "${finalchoice[@]}"
    pacman -S --needed --noconfirm git base-devel
    
    git clone https://aur.archlinux.org/yay-bin.git && chmod 777 yay-bin && cd yay-bin 

    env -i HOME="$HOME" USER="$real_user" LOGNAME="$real_user" \
    runuser -u "$real_user" -- makepkg -si --noconfirm
    cd ~   # Now this resolves to /home/$real_user
    env -i HOME="$user_home" USER="$real_user" LOGNAME="$real_user" \
        runuser -u "$real_user" -- yay -S --noconfirm 
    
    sudo -u $real_user yay -S --noconfirm visual-studio-code-bin spotify wlogout visual-studio-code-bin 

    cd ~ && git clone https://github.com/Typhoonz0/dots.git && cd dots || exit

    for dir in "${!map[@]}"; do
        mkdir -p "$HOME/.config/$dir"
        cp -r "$dir/"* "$HOME/.config/$dir/" 2>/dev/null
    done

    cp .zshrc ~/

  #  --- Firefox binary not installed yet, appearently? ---
  #  git clone https://github.com/Typhoonz0/archfr
  #  for file in archfr/firefox-ext*; do
  #      firefox "$file"
  #  done

  #  curl -LO https://github.com/catppuccin/vscode/releases/download/catppuccin-vsc-v3.17.0/catppuccin-vsc-3.17.0.vsix
  #  code --install-extension catppuccin-vsc-3.17.0.vsix

  #  curl -LO https://extensions.gnome.org/extension-data/dash-to-dockmicxgx.gmail.com.v71.shell-extension.zip
  #  curl -LO https://github.com/aunetx/blur-my-shell/releases/download/v68-2/blur-my-shell@aunetx.shell-extension.zip
  #  curl -LO https://github.com/tiagoporsch/restartto/releases/download/8/restartto@tiagoporsch.github.io.shell-extension.zip
  #  gnome-extensions install ./custom-hot-corners-extendedG-dH.github.com.v11.shell-extension.zip
  #  gnome-extensions install ./dash-to-dockmicxgx.gmail.com.v71.shell-extension.zip
  #  gnome-extensions install ./restartto@tiagoporsch.github.io.shell-extension.zip

  #  gsettings set org.gnome.desktop.background picture-uri file:///~/.config/hypr/dunes.jpg
  #  gsettings set org.gnome.desktop.wm.preferences button-layout :minimize,maximize,close
  #  gsettings set org.gnome.shell.extensions.system-monitor show-cpu true
  #  gsettings set org.gnome.shell.extensions.system-monitor show-memory true
  #  gsettings set org.gnome.shell.extensions.system-monitor show-swap true

    cd ~ && rm -rf archfr yay-bin blur-my-shell@aunetx.shell-extension.zip dash-to-dockmicxgx.gmail.com.v71.shell-extension.zip catppuccin-vsc-3.17.0.vsix

}

finalize() {
    [[ "$dechoice" = 2  ]] && echo "exec Hyprland" >> ~/.zshrc
    [[ "$dechoice" =~ ^[13]$  ]] && systemctl enable gdm &>/dev/null
    echo "Finished! Press ENTER to reboot."
    read 
    reboot now 
}

echo -ne "
-------------------------------------------------------------------------

    █████╗ ██████╗  ██████╗██╗  ██╗███████╗██████╗ 
   ██╔══██╗██╔══██╗██╔════╝██║  ██║██╔════╝██╔══██╗
   ███████║██████╔╝██║     ███████║█████╗  ██████╔╝         by
   ██╔══██║██╔══██╗██║     ██╔══██║██╔══╝  ██╔══██╗     typhoonz0
   ██║  ██║██║  ██║╚██████╗██║  ██║██║     ██║  ██║
   ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚═╝     ╚═╝  ╚═╝

-------------------------------------------------------------------------
                         Post Install

1) Minimal: Select your desktop environment (Gnome, Hyprland, both, or neither) + git, firefox, terminal, nvim, lf, yay
2) My Setup: Gnome + Hyprland, includes minimal tools + libreoffice, steam, discord, gparted, and my theming
0) Skip post-installation (exit script)
"

read -rp "Choice: " choice; choice=${choice:-0}
case "$choice" in
    1) minimal; finalize ;;
    2) default; finalize ;;
    *) echo "Exiting script."; exit ;;
esac
