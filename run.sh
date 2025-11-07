#!/bin/bash
# Copyright (c) [2024] [@ravindu644]

export DEBIAN_FRONTEND=noninteractive

# ───────────────────────────────────────────────────────────────
# Function: Create new user with sudo and bash shell
# ───────────────────────────────────────────────────────────────
create_user() {
    echo "Creating User and Setting it up"
    read -p "Enter username: " username
    read -s -p "Enter password: " password
    echo

    useradd -m "$username"
    adduser "$username" sudo
    echo "$username:$password" | sudo chpasswd
    sed -i 's/\/bin\/sh/\/bin\/bash/g' /etc/passwd

    echo 'export PATH=$PATH:/home/user/.local/bin' >> /home/"$username"/.bashrc
    su - "$username" -c "source ~/.bashrc"

    echo "User created and configured having username '$username'"
}

# ───────────────────────────────────────────────────────────────
# Function: Create and mount 20 GB virtual disk as extra storage
# ───────────────────────────────────────────────────────────────
setup_storage() {
    local username="$1"
    local STORAGE_FILE="/mnt/extra_storage.img"
    local STORAGE_MOUNT="/storage"

    echo "Setting up 20GB of extra storage..."

    # Create and format disk image if not already present
    if [[ ! -f "$STORAGE_FILE" ]]; then
        echo "Creating 20GB virtual disk at $STORAGE_FILE..."
        fallocate -l 20G "$STORAGE_FILE" || dd if=/dev/zero of="$STORAGE_FILE" bs=1G count=20
        mkfs.ext4 -F "$STORAGE_FILE"
    fi

    # Mount the virtual disk
    mkdir -p "$STORAGE_MOUNT"
    mount -o loop "$STORAGE_FILE" "$STORAGE_MOUNT"

    # Set permissions and bind to user's home directory
    chmod 777 "$STORAGE_MOUNT"
    chown "$username":"$username" "$STORAGE_MOUNT"

    mkdir -p /home/"$username"/storage
    mount --bind "$STORAGE_MOUNT" /home/"$username"/storage

    echo "$STORAGE_FILE $STORAGE_MOUNT ext4 loop 0 0" >> /etc/fstab
    echo "$STORAGE_MOUNT /home/$username/storage none bind 0 0" >> /etc/fstab

    echo "Extra 20GB storage mounted at $STORAGE_MOUNT and bound to /home/$username/storage"
}

# ───────────────────────────────────────────────────────────────
# Function: Install and configure Chrome Remote Desktop + XFCE
# ───────────────────────────────────────────────────────────────
setup_rdp() {
    echo "Installing Firefox ESR"
    add-apt-repository ppa:mozillateam/ppa -y  
    apt update
    apt install --assume-yes firefox-esr dbus-x11 dbus 

    echo "Installing dependencies"
    add-apt-repository universe -y
    apt update
    apt install --assume-yes xvfb xserver-xorg-video-dummy xbase-clients \
        python3-packaging python3-psutil python3-xdg libgbm1 libutempter0 \
        libfuse2 nload qbittorrent ffmpeg gpac fonts-lklug-sinhala

    echo "Installing Desktop Environment"
    apt install --assume-yes xfce4 desktop-base xfce4-terminal xfce4-session
    bash -c 'echo "exec /etc/X11/Xsession /usr/bin/xfce4-session" > /etc/chrome-remote-desktop-session'
    apt remove --assume-yes gnome-terminal
    apt install --assume-yes xscreensaver
    systemctl disable lightdm.service

    echo "Installing Chrome Remote Desktop"
    wget https://dl.google.com/linux/direct/chrome-remote-desktop_current_amd64.deb
    dpkg --install chrome-remote-desktop_current_amd64.deb
    apt install --assume-yes --fix-broken

    echo "Finalizing Chrome Remote Desktop setup"
    adduser "$username" chrome-remote-desktop

    echo "Please visit http://remotedesktop.google.com/headless and copy the command after Authentication"
    read -p "Paste the CRD command here: " CRP
    read -p "Enter a PIN for CRD (6 or more digits): " Pin

    su - "$username" -c "$CRP --pin=$Pin"
    service chrome-remote-desktop start

    setup_storage "$username"

    echo "RDP setup completed successfully."
}

# ───────────────────────────────────────────────────────────────
# Main Execution
# ───────────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

create_user
setup_rdp

echo "Setup completed. Please check the individual function outputs for access information."

# Keep-alive loop
echo "Starting keep-alive loop. Press Ctrl+C to stop."
while true; do
    echo "I'm alive"
    sleep 300
done
