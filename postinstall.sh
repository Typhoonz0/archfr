#!/usr/bin/bash
# Post install script to make the system useful
essentialpkgs=(git firefox ghostty neovim lf)
suggestedpkgs=(libreoffice-still btop steam fastfetch tmux cmatrix lolcat discord gparted nautilus firefox swaybg blueberry)
yaypkgs=(visual-studio-code-bin spotify uxplay wlogout)
finalchoice="gnome hyprland"

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
        1) finalchoice="gnome" ;;
        2) finalchoice="hyprland" ;;
        3) finalchoice="gnome hyprland" ;;
        *) finalchoice="none" ;;
    esac
    pacman -S --noconfirm "${essentialpkgs[@]}" || true
    [[ "$finalchoice" != "none" ]] && pacman -S --noconfirm "${finalchoice[@]}" || true
}

default() {
    declare -A map=( [fastfetch]=fastfetch [ghostty]=ghostty [hypr]=hyprland [nvim]=neovim [rofi]=rofi [tmux]=tmux [waybar]=waybar [zsh]=zsh )

    pacman -Sy --noconfirm
    pacman -S --noconfirm "${essentialpkgs[@]}" "${suggestedpkgs[@]}" || true

    pacman -S --needed --noconfirm git base-devel
    git clone https://aur.archlinux.org/yay-bin.git && cd yay-bin && makepkg -si --noconfirm
    cd ~ && rm -rf yay-bin

    sudo -u liam yay -S --noconfirm "${yaypkgs[@]}" || true

    cd ~ && git clone https://github.com/Typhoonz0/dots.git && cd dots || exit

    for dir in "${!map[@]}"; do
        mkdir -p "$HOME/.config/$dir"
        cp -r "$dir/"* "$HOME/.config/$dir/" 2>/dev/null
    done

    cp .zshrc ~/
}

finalize() {
    [[ "$finalchoice" == *hyprland* ]] && echo "exec Hyprland" >> ~/.zshrc
    [[ "$finalchoice" == *gnome* ]] && systemctl enable gdm &>/dev/null
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
