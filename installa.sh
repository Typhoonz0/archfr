#!/usr/bin/env bash
set -euo pipefail

# === CONFIG ===
HOSTNAME="archlinux"
USERNAME="user"
PASSWORD="root"
DOTFILES_REPO="https://github.com/Typhoonz0/dots.git"

# Official packages
ESSENTIAL_PKGS=(
  base linux linux-firmware
  git sudo man
  networkmanager openssh
  base-devel
)

# Custom packages (pacman)
CUSTOM_PKGS=(
    blueberry
    blueman
    cmatrix
    discord
    fastfetch
    firefox
    gnome
    gparted
    grim
    ghostty
    hyprland
    libreoffice
    lolcat
    nautilus
    neovim
    os-prober
    rofi
    slurp
    swaybg
    tmux
    waybar
    zsh
)
# AUR packages
AUR_PKGS=(
  visual-studio-code-bin
)

# === FUNCTIONS ===

check_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    echo "Run as root inside Arch ISO."
    exit 1
  fi
}

validate_network() {
  if ! ping -c 1 archlinux.org &>/dev/null; then
    echo "No network connection. Connect first!"
    exit 1
  fi
}

partition_menu() {
  echo "[*] Select partitioning method:"
  echo "1) Wipe disk (use cfdisk interactively)"
  echo "2) Use existing partition (manual selection)"
  read -rp "Choice [1-2]: " choice
  
  case "$choice" in
    1)
      lsblk
      read -rp "Enter target disk (e.g. /dev/sda): " disk
      echo "[*] Launching cfdisk on $disk..."
      cfdisk "$disk"
      echo "[*] Partitioning done. Please remember your root partition!"
      ;;
    2)
      lsblk
      read -rp "Enter existing root partition (e.g. /dev/sda2): " partition
      ROOT_PART="$partition"
      ;;
    *)
      echo "Invalid choice."
      exit 1
      ;;
  esac
}

format_and_mount() {
  if [[ -z "${ROOT_PART:-}" ]]; then
    lsblk
    read -rp "Enter root partition to format (e.g. /dev/sda2): " ROOT_PART
  fi
  echo "[*] Formatting $ROOT_PART as ext4..."
  mkfs.ext4 -F "$ROOT_PART"
  echo "[*] Mounting $ROOT_PART to /mnt..."
  mount "$ROOT_PART" /mnt
}

install_base() {
  echo "[*] Installing base system..."
  pacstrap /mnt "${ESSENTIAL_PKGS[@]}" "${CUSTOM_PKGS[@]}"
}

gen_fstab() {
  echo "[*] Generating fstab..."
  genfstab -U /mnt >> /mnt/etc/fstab
}

chroot_setup() {
  echo "[*] Chrooting into system..."
  arch-chroot /mnt /bin/bash <<EOF
    set -euo pipefail

    echo "$HOSTNAME" > /etc/hostname
    ln -sf /usr/share/zoneinfo/UTC /etc/localtime
    hwclock --systohc
    sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
    locale-gen
    echo "LANG=en_US.UTF-8" > /etc/locale.conf
    echo "$USERNAME:$PASSWORD" | chpasswd
    useradd -m -G wheel -s /bin/bash "$USERNAME" || true
    echo "$USERNAME ALL=(ALL) ALL" >> /etc/sudoers

    systemctl enable NetworkManager
EOF
}

install_yay() {
  echo "[*] Installing yay..."
  arch-chroot /mnt /bin/bash <<EOF
    set -euo pipefail
    sudo -u "$USERNAME" bash <<INNER
      cd ~
      if [[ ! -d yay ]]; then
        git clone https://aur.archlinux.org/yay.git
      fi
      cd yay
      makepkg -si --noconfirm
      yay -S --noconfirm ${AUR_PKGS[*]}
INNER
EOF
}

install_dotfiles() {
  echo "[*] Installing dotfiles..."
  arch-chroot /mnt /bin/bash <<EOF
    set -euo pipefail
    sudo -u "$USERNAME" bash <<'INNER'
      if [[ ! -d ~/dotfiles ]]; then
        git clone "$DOTFILES_REPO" ~/dotfiles
      fi
      cd ~/dotfiles

      mkdir -p ~/.config
      for dir in */; do
        d=\${dir%/}
        if [[ -d "\$d" ]]; then
          mkdir -p "\$HOME/.config/\$d"
          cp -r "\$d/"* "\$HOME/.config/\$d/" 2>/dev/null || true
        fi
      done

      if [[ -f .zshrc ]]; then
        cp .zshrc ~/.zshrc
      fi
INNER
EOF
}


# === MAIN ===
check_root
validate_network
partition_menu
format_and_mount
install_base
gen_fstab
chroot_setup
install_yay
install_dotfiles

echo "[*] Install finished. You may reboot now."
