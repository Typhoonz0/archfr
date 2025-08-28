#!/usr/bin/env bash
set -euo pipefail

# base packages
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
    eza
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
  wlogout
  wl-gammarelay 
)

# === FUNCTIONS ===

get_info() {
    DOTFILES_REPO="https://github.com/Typhoonz0/dots.git"

    while true; do
        read -rp "Username [user]: " username
        username=${username:-user}
        if [[ "$username" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
            USERNAME="$username"
            break
        else
            echo "Invalid username. Must start with a letter/underscore, lowercase only, and contain only [a-z0-9_-]."
        fi
    done

    while true; do
        read -rp "Hostname [archfr]: " host
        host=${host:-autoarch}
        if [[ "$host" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]*$ ]]; then
            HOSTNAME="$host"
            break
        else
            echo "Invalid hostname. Must be alphanumeric and may include dashes (but not start with one)."
        fi
    done

    while true; do
        read -rsp "User password [root]: " userpass
        echo
        userpass=${userpass:-root}
        if [[ -n "$userpass" ]]; then
            PASSWORD="$userpass"
            break
        else
            echo "Password cannot be empty."
        fi
    done

    while true; do
        read -rsp "Root password [root]: " rootpass
        echo
        rootpass=${rootpass:-root}
        if [[ -n "$rootpass" ]]; then
            ROOTPASS="$rootpass"
            break
        else
            echo "Root password cannot be empty."
        fi
    done

    while true; do
        read -rp "Timezone [Australia/Sydney]: " timezone
        timezone=${timezone:-Australia/Sydney}
        if [[ -f "/usr/share/zoneinfo/$timezone" ]]; then
            TIMEZONE="$timezone"
            break
        else
            echo "Invalid timezone. "
        fi
    done

    while true; do
        read -rp "Swapfile size in GB [0]: " swapfilesize
        swapfilesize=${swapfilesize:-0}
        if [[ "$swapfilesize" =~ ^[0-9]+$ ]]; then
            SWAPFILESIZE="$swapfilesize"
            break
        else
            echo "Swapfile size must be a non-negative integer."
        fi
    done
}

checks() {
  [ -d /run/archiso ] || { echo "You have already installed Arch!"; exit 1; }
  [ "$(id -u)" -eq 0 ] || { echo "Please run as root."; exit 1; }
  grep -qi '^ID=arch' /etc/os-release || { echo "Not an Arch Linux ISO!"; exit 1; }
  [ "$(cat /sys/firmware/efi/fw_platform_size 2>/dev/null)" = 64 ] || { echo "Not a UEFI system."; exit 1; }
}

validate_network() {
  if ! ping -c 1 archlinux.org &>/dev/null; then
    echo "No network connection. Connect first!"
    exit 1
  fi
}

partition_menu() {
  echo "[*] Select partitioning method:"
  echo "1) Edit partitions with cfdisk"
  echo "2) Use existing partitions"
  read -rp "Choice [1-2]: " choice

  case "$choice" in
    1)
      lsblk
      while true; do
        read -rp "Enter target disk (e.g. /dev/sda): " disk
        if [[ -b "$disk" ]]; then
          echo "[*] Launching cfdisk on $disk..."
          cfdisk "$disk"
          echo "[*] Partitioning done. Please remember your root and EFI partitions!"
          break
        else
          echo "Invalid disk. Please enter a valid block device (e.g. /dev/sda)."
        fi
      done
      ;;
    2)
      ;;
    *)
      echo "Invalid choice."
      exit 1
      ;;
  esac

  lsblk

  while true; do
    read -rp "Enter root partition (e.g. /dev/sda2): " ROOT_PART
    if [[ -b "$ROOT_PART" ]]; then
      if ! mount | grep -q "on $ROOT_PART "; then
        break
      else
        echo "Partition $ROOT_PART is already mounted. Choose another."
      fi
    else
      echo "Invalid root partition."
    fi
  done

  while true; do
    read -rp "Enter EFI partition (e.g. /dev/sda1): " EFI_PART
    if [[ -b "$EFI_PART" ]]; then
      if ! mount | grep -q "on $EFI_PART "; then
        break
      else
        echo "Partition $EFI_PART is already mounted. Choose another."
      fi
    else
      echo "Invalid EFI partition."
    fi
  done

  echo
  echo "[!] WARNING: This will format $ROOT_PART as ext4."
  read -rp "Are you sure? This will erase ALL data on this partition. (yes/[no]): " confirm
  if [[ "$confirm" != "yes" ]]; then
    echo "Aborting."
    exit 1
  fi

  echo "[*] Formatting root partition $ROOT_PART as ext4..."
  mkfs.ext4 -F "$ROOT_PART"
  read -rp "Format EFI partition $EFI_PART? Only needed if the EFI partition was just created. (y/n): " confirmformat
  [[ "$confirmformat" =~ ^[Yy]$ ]] && mkfs.fat -F32 "$EFI_PART"
  echo "[*] Mounting partitions..."
  mount "$ROOT_PART" /mnt
  mkdir -p /mnt/boot/efi
  mount "$EFI_PART" /mnt/boot/efi
}

install_base() {
  echo "[*] Installing base system..."
  pacstrap /mnt "${ESSENTIAL_PKGS[@]}" "${CUSTOM_PKGS[@]}"
}

gen_swapfile() {
  if [[ "$SWAPFILESIZE" != 0 ]]; then
    dd if=/dev/zero of=/mnt/swapfile bs=1M count=$((SWAPFILESIZE*1024)) status=progress
    chmod 600 /mnt/swapfile
    mkswap /mnt/swapfile
    swapon /mnt/swapfile
  fi
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
    ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
    hwclock --systohc
    sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
    locale-gen
    echo "LANG=en_US.UTF-8" > /etc/locale.conf

    useradd -m -G wheel -s /bin/bash "$USERNAME" || true
    echo "$USERNAME:$PASSWORD" | chpasswd
    echo "root:$ROOTPASS" | chpasswd
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
echo "version 0.0.2"
get_info
checks
validate_network
partition_menu
install_base
gen_swapfile
gen_fstab
chroot_setup
install_grub
install_yay
install_dotfiles

echo "[*] Install finished. You may reboot now."
