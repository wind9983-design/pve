#!/bin/bash

# Proxmox VE 配置脚本
# 支持 PVE 7/8/9 版本
# 功能：1. 安装常用命令 2. 更新系统 3. 更换 apt 源和 CT 模板源

# 确保以 root 用户运行
if [ "$(id -u)" != "0" ]; then
   echo "此脚本必须以 root 用户运行，请使用 sudo 或以 root 身份执行。" 1>&2
   exit 1
fi

# 检测 PVE 版本
PVE_VERSION=$(pveversion | grep -oP 'pve-manager/\K[0-9]' || echo "")
if [ -z "$PVE_VERSION" ]; then
    echo "无法检测 PVE 版本。请确保已安装 Proxmox VE。" 1>&2
    exit 1
fi

echo "检测到 PVE 版本: $PVE_VERSION"

# 支持的版本检查
if [[ ! "$PVE_VERSION" =~ ^(7|8|9)$ ]]; then
    echo "此脚本仅支持 PVE 7/8/9 版本。" 1>&2
    exit 1
fi

# 安装常用命令
echo "正在安装常用命令：curl, wget, vim, net-tools, htop, git, unzip, zip..."
if ! apt update; then
    echo "apt update 失败，请检查网络连接。" 1>&2
    exit 1
fi
if ! apt install -y curl wget vim net-tools htop git unzip zip; then
    echo "安装常用命令失败，请检查 apt 输出。" 1>&2
    exit 1
fi

# 更新系统
echo "正在更新系统..."
if ! apt update || ! apt upgrade -y; then
    echo "系统更新失败，请检查错误信息。" 1>&2
    exit 1
fi

# 选择镜像源（默认清华源，允许用户自定义）
MIRROR="https://mirrors.tuna.tsinghua.edu.cn"
read -p "请输入镜像源 (默认: $MIRROR): " CUSTOM_MIRROR
if [ -n "$CUSTOM_MIRROR" ]; then
    MIRROR="$CUSTOM_MIRROR"
fi

# 备份原有源文件
BACKUP_DIR="/etc/apt/sources.list.d/backup-$(date +%F-%H%M%S)"
mkdir -p "$BACKUP_DIR"
[ -f /etc/apt/sources.list ] && cp /etc/apt/sources.list "$BACKUP_DIR/sources.list.bak"
[ -f /etc/apt/sources.list.d/pve-enterprise.list ] && cp /etc/apt/sources.list.d/pve-enterprise.list "$BACKUP_DIR/pve-enterprise.list.bak"

# 确定 Debian 和 Ceph 版本
CODENAME=""
CEPH_VERSION=""
case $PVE_VERSION in
    7)
        CODENAME="bullseye"
        CEPH_VERSION="quincy"
        ;;
    8)
        CODENAME="bookworm"
        CEPH_VERSION="reef"
        ;;
    9)
        CODENAME="trixie"  # 假设 PVE 9 基于 Debian 13 trixie，需确认
        CEPH_VERSION="squid"  # 假设最新 Ceph 版本
        ;;
esac

# 更换 apt 源
echo "正在更换 apt 源为 $MIRROR..."

cat <<EOF > /etc/apt/sources.list
deb $MIRROR/debian/ $CODENAME main contrib non-free non-free-firmware
deb $MIRROR/debian/ $CODENAME-updates main contrib non-free non-free-firmware
deb $MIRROR/debian/ $CODENAME-backports main contrib non-free non-free-firmware
deb $MIRROR/debian-security $CODENAME-security main contrib non-free non-free-firmware
EOF

# PVE no-subscription 源
cat <<EOF > /etc/apt/sources.list.d/pve-no-subscription.list
deb https://download.proxmox.com/debian/pve $CODENAME pve-no-subscription
EOF

# 禁用企业源
echo "#deb https://enterprise.proxmox.com/debian/pve $CODENAME pve-enterprise" > /etc/apt/sources.list.d/pve-enterprise.list

# 处理 Ceph 源
if [ -f /etc/apt/sources.list.d/ceph.list ]; then
    cp /etc/apt/sources.list.d/ceph.list "$BACKUP_DIR/ceph.list.bak"
    echo "deb https://download.proxmox.com/debian/ceph-$CEPH_VERSION $CODENAME no-subscription" > /etc/apt/sources.list.d/ceph.list
fi

# 更新 apt 源
echo "正在更新 apt 源..."
if ! apt update; then
    echo "apt update 失败，请检查网络连接或镜像源是否可用。" 1>&2
    exit 1
fi

# 更新 CT 模板源
echo "正在更新 CT 模板源..."
if ! pveam update; then
    echo "警告：CT 模板源更新失败，可能需要检查网络或配置代理。" 1>&2
fi

echo "脚本执行完成！"
echo "备份文件已保存至 $BACKUP_DIR"
echo "注意：请验证镜像源 $MIRROR 的可用性，并根据需要调整源配置。"
