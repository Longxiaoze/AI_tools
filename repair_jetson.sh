#!/bin/bash
echo "=== Jetson Auto Repair Tool ==="

# 0. 检查 root 权限
if [ "$(id -u)" -ne 0 ]; then
    echo "[ERROR] Please run as root"
    exit 1
fi

# 1. 重新挂载根分区为可写
echo "[INFO] Remounting root filesystem..."
mount -o remount,rw /

# 2. 修复丢失的系统目录
echo "[INFO] Checking critical directories..."
for dir in /var /var/log /var/tmp /var/lib /var/run; do
    if [ ! -d "$dir" ]; then
        echo "[FIX] Creating $dir"
        mkdir -p $dir
    fi
done
chmod 755 /var /var/log /var/lib /var/run
chmod 1777 /var/tmp

# 3. 检查 systemd 必要目录
mkdir -p /var/lib/systemd /var/run/systemd
chmod 755 /var/lib/systemd /var/run/systemd

# 4. 检查 fstab，注释掉无效挂载
echo "[INFO] Checking /etc/fstab..."
cp /etc/fstab /etc/fstab.bak
grep -v '^#' /etc/fstab | while read -r line; do
    DEV=$(echo $line | awk '{print $1}')
    if [[ "$DEV" == UUID=* || "$DEV" == /dev/* ]]; then
        if [ ! -e "$DEV" ]; then
            echo "[WARN] Invalid device: $DEV -> commenting out"
            sed -i "s|^$DEV|#$DEV|g" /etc/fstab
        fi
    fi
done

# 5. 如果 apt 可用，修复包并恢复 GUI
if command -v apt-get &> /dev/null; then
    echo "[INFO] Updating package index..."
    apt-get update || true
    echo "[INFO] Fixing broken packages..."
    apt-get install --fix-broken -y || true
    echo "[INFO] Reinstalling GUI components..."
    apt-get install --reinstall -y nvidia-l4t-gui-tools gdm3 || true
fi

# 6. 重启 systemd
echo "[INFO] Reloading systemd..."
systemctl daemon-reexec

echo "[DONE] Repair complete. Please reboot."
