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
  echo "2) Use existing partitions (manual selection)"
  read -rp "Choice [1-2]: " choice
  
  case "$choice" in
    1)
      lsblk
      read -rp "Enter target disk (e.g. /dev/sda): " disk
      echo "[*] Launching cfdisk on $disk..."
      cfdisk "$disk"
      echo "[*] Partitioning done. Please remember your root and EFI partitions!"
      ;;
    2)
      ;;
    *)
      echo "Invalid choice."
      exit 1
      ;;
  esac

  lsblk
  read -rp "Enter root partition (e.g. /dev/sda2): " ROOT_PART
  read -rp "Enter EFI partition (e.g. /dev/sda1): " EFI_PART

  echo "[*] Formatting root partition $ROOT_PART as ext4..."
  mkfs.ext4 -F "$ROOT_PART"
  echo "[*] Formatting EFI partition $EFI_PART as FAT32..."
  mkfs.fat -F32 "$EFI_PART"

  echo "[*] Mounting partitions..."
  mount "$ROOT_PART" /mnt
  mkdir -p /mnt/boot/efi
  mount "$EFI_PART" /mnt/boot/efi
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
  echo "[*] Setting up system in chroot..."
  arch-chroot /mnt /bin/bash <<EOF
    set -euo pipefail

    echo "$HOSTNAME" > /etc/hostname
    ln -sf /usr/share/zoneinfo/UTC /etc/localtime
    hwclock --systohc
    sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
    locale-gen
    echo "LANG=en_US.UTF-8" > /etc/locale.conf

    useradd -m -G wheel -s /bin/bash "$USERNAME" || true
    echo "$USERNAME:$PASSWORD" | chpasswd
    echo "$USERNAME ALL=(ALL) ALL" >> /etc/sudoers

    systemctl enable NetworkManager
EOF
}

install_grub() {
  echo "[*] Installing GRUB bootloader..."
  arch-chroot /mnt /bin/bash <<EOF
    set -euo pipefail

    pacman -S --noconfirm grub efibootmgr

    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
    grub-mkconfig -o /boot/grub/grub.cfg
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
echo "version 0.0.1"
check_root
validate_network
partition_menu
install_base
gen_fstab
chroot_setup
install_grub
install_yay
install_dotfiles

echo "[*] Install finished. You may reboot now."
