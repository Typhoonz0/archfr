#!/bin/bash
# ArchFR - An Arch meta-distro

# Downloading bonus script
curl https://github.com/Typhoonz0/archfr/raw/refs/heads/main/postinstall.sh -o postinstall.sh 

banner() {
    echo -ne "
    -------------------------------------------------------------------------

       █████╗ ██████╗  ██████╗██╗  ██╗███████╗██████╗ 
      ██╔══██╗██╔══██╗██╔════╝██║  ██║██╔════╝██╔══██╗
      ███████║██████╔╝██║     ███████║█████╗  ██████╔╝         by
      ██╔══██║██╔══██╗██║     ██╔══██║██╔══╝  ██╔══██╗     typhoonz0
      ██║  ██║██║  ██║╚██████╗██║  ██║██║     ██║  ██║
      ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚═╝     ╚═╝  ╚═╝

    -------------------------------------------------------------------------
    "
}

clear
banner

# Sanity checks
[ -d /run/archiso ] || { echo "You have already installed Arch!"; exit 1; }
[ "$(id -u)" -eq 0 ] || { echo "Please run as root."; exit 1; }
grep -qi '^ID=arch' /etc/os-release || { echo "Not an Arch Linux ISO!"; exit 1; }
[ "$(cat /sys/firmware/efi/fw_platform_size 2>/dev/null)" = 64 ] || { echo "Not a UEFI system."; exit 1; }
# [ ping -c 1 -W 2 8.8.8.8 &>/dev/null ] || { echo "You lost internet... How??"; exit 1; }

# User details
echo -ne "
          Only vital selections are checked, be careful typing
-------------------------------------------------------------------------
                        Enter your details
-------------------------------------------------------------------------
"

read -rp "Username [user]: " username; username=${username:-user}
read -rp "Hostname [archfr]: " host; host=${host:-autoarch}
read -rp "User password [root]: " userpass; userpass=${userpass:-root}
read -rp "Root password [root]: " rootpass; rootpass=${rootpass:-root}
read -rp "Locale [en_US.UTF-8 UTF-8]: " locale; locale=${locale:-en_US.UTF-8 UTF-8}
read -rp "Timezone [Australia/Sydney]: " timezone; timezone=${timezone:-Australia/Sydney}
read -rp "Swapfile size in GB [0]: " swapfilesize; swapfilesize=${swapfilesize:-0}

diskpart() {
    # Partitioning
    lsblk
    read -rp "Select disk (e.g., /dev/sda): " DISK
    [[ -b "$DISK" ]] || { echo "Invalid disk."; diskpart; }
    read -rp "Use (a) auto partition or (b) manual? [a/b]: " autopartconfirm
}

echo -ne "
-------------------------------------------------------------------------
                        Disk Partitioning
-------------------------------------------------------------------------
"
diskpart 

manual_part_2() {
    lsblk
    read -rp "EFI partition (e.g., /dev/sda1): " EFI_PART
    [[ -b "$EFI_PART" ]] || { echo "Invalid EFI partition."; manual_part_2; }
    read -rp "Root partition (e.g., /dev/sda2): " ROOT_PART
    [[ -b "$ROOT_PART" ]] || { echo "Invalid root partition. "; manual_part_2; }
    read -rp "Format EFI partition $EFI_PART? Only needed if the EFI partition was just created. (y/n): " confirmformat
    [[ "$confirmformat" =~ ^[Yy]$ ]] && mkfs.fat -F32 "$EFI_PART"
}

manual_part() {
    read -p "Use cfdisk to partition. Press ENTER to continue."
    cfdisk "$DISK"
    manual_part_2
}

if [[ "$autopartconfirm" == "a" ]]; then
    read -rp "WARNING: Erases all data on $DISK. Confirm (yes/no): " confirm
    if [[ "$confirm" =~ ^(yes|y)$ ]]; then
        parted "$DISK" --script mklabel gpt
        parted "$DISK" --script mkpart ESP fat32 1MiB 512MiB
        parted "$DISK" --script set 1 boot on
        parted "$DISK" --script mkpart primary ext4 512MiB 100%
        EFI_PART="${DISK}1"; ROOT_PART="${DISK}2"
        mkfs.fat -F32 "$EFI_PART"
    else
        manual_part
    fi
else
    manual_part
fi

echo -ne "
-------------------------------------------------------------------------
                    Formatting and mounting drives
-------------------------------------------------------------------------
"
# Mount and install
mkfs.ext4 "$ROOT_PART"
mount "$ROOT_PART" /mnt
mount --mkdir "$EFI_PART" /mnt/boot/efi

sed -i '/^SigLevel/c\SigLevel = Never' /etc/pacman.conf

# Install the essentials to boot, everything else can be in postinstall.sh
echo -ne "
-------------------------------------------------------------------------
                        Installing base system
-------------------------------------------------------------------------
"
pacstrap /mnt base linux linux-firmware sudo nano networkmanager grub efibootmgr zsh

if [[ "$swapfilesize" != 0 ]]; then
    dd if=/dev/zero of=/mnt/swapfile bs=1M count=$((swapfilesize*1024)) status=progress
    chmod 600 /mnt/swapfile
    mkswap /mnt/swapfile
    swapon /mnt/swapfile
fi

genfstab -U /mnt >> /mnt/etc/fstab

chmod +x postinstall.sh
mv /mnt/etc/pacman.conf /mnt/etc/pacman.conf.bak
cp /etc/pacman.conf /mnt/etc/pacman.conf

# Chroot configuration
arch-chroot /mnt /bin/bash <<EOF
ln -sf /usr/share/zoneinfo/$timezone /etc/localtime
hwclock --systohc
sed -i 's/#$locale/$locale/' /etc/locale.gen
locale-gen
echo "LANG=${locale%% *}" > /etc/locale.conf
echo "$host" > /etc/hostname
echo "root:$rootpass" | chpasswd
useradd -m -G wheel $username
echo "$username:$userpass" | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
chsh -s /usr/bin/zsh $username
echo "echo 'Running post-install script...' && sudo chmod +x postinstall.sh && sudo postinstall.sh" >> /home/$username/.zshrc
mkinitcpio -P
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --modules="tpm" --disable-shim-lock
grub-mkconfig -o /boot/grub/grub.cfg
EOF
cp postinstall.sh /mnt/home/$username/postinstall.sh
systemctl --root=/mnt enable NetworkManager &>/dev/null
clear
banner
echo -ne "

   Installed ArchFR, run 'reboot' and login as your user to finalize.
-------------------------------------------------------------------------
"
