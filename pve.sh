#!/bin/bash

# Proxmox VE 版本检测和换源脚本
# 支持 PVE 7/8/9 版本
# 功能：1. 换 apt 源和 CT 模板源 2. 更新系统 3. 安装常用命令

# 确保以 root 用户运行
if [ "$(id -u)" != "0" ]; then
   echo "此脚本必须以 root 用户运行" 1>&2
   exit 1
fi

# 检测 PVE 版本
PVE_VERSION=$(pveversion | grep -oP 'pve-manager/\K[0-9]')
if [ -z "$PVE_VERSION" ]; then
    echo "无法检测 PVE 版本。请确保已安装 Proxmox VE。"
    exit 1
fi

echo "检测到 PVE 版本: $PVE_VERSION"

# 支持的版本检查
if [[ ! "$PVE_VERSION" =~ ^(7|8|9)$ ]]; then
    echo "此脚本仅支持 PVE 7/8/9 版本。"
    exit 1
fi

# 备份原有源文件
cp /etc/apt/sources.list /etc/apt/sources.list.bak
cp /etc/apt/sources.list.d/pve-enterprise.list /etc/apt/sources.list.d/pve-enterprise.list.bak 2>/dev/null

# 换 apt 源：禁用企业源，启用 no-subscription 源
echo "正在更换 apt 源..."

# 对于 PVE 7/8/9，源格式类似，但 codename 不同
CODENAME=""
case $PVE_VERSION in
    7) CODENAME="bullseye" ;;
    8) CODENAME="bookworm" ;;
    9) CODENAME="trixie" ;;  # 假设 PVE 9 基于 Debian 13 trixie，实际需确认
esac

# 主 sources.list：使用清华镜像或其他国内镜像，这里用清华源作为示例
cat <<EOF > /etc/apt/sources.list
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ $CODENAME main contrib non-free non-free-firmware
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ $CODENAME-updates main contrib non-free non-free-firmware
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ $CODENAME-backports main contrib non-free non-free-firmware
deb https://mirrors.tuna.tsinghua.edu.cn/debian-security $CODENAME-security main contrib non-free non-free-firmware
EOF

# PVE no-subscription 源，使用官方或镜像
cat <<EOF > /etc/apt/sources.list.d/pve-no-subscription.list
deb https://download.proxmox.com/debian/pve $CODENAME pve-no-subscription
EOF

# 禁用企业源
echo "#deb https://enterprise.proxmox.com/debian/pve $CODENAME pve-enterprise" > /etc/apt/sources.list.d/pve-enterprise.list

# 对于 Ceph，如果安装了
if [ -f /etc/apt/sources.list.d/ceph.list ]; then
    cp /etc/apt/sources.list.d/ceph.list /etc/apt/sources.list.d/ceph.list.bak
    echo "deb https://download.proxmox.com/debian/ceph-quincy $CODENAME no-subscription" > /etc/apt/sources.list.d/ceph.list
    # 根据版本调整 ceph 版本，如 quincy, reef 等
fi

# 更新 apt 源
apt update

# 更换 CT 模板源：更新模板列表
echo "正在更新 CT 模板源..."
pveam update

# 更新系统
echo "正在更新系统..."
apt update && apt full-upgrade -y

# 安装常用命令
echo "正在安装常用命令：curl, wget, vim, net-tools, htop, git 等..."
apt install -y curl wget vim net-tools htop git unzip zip

echo "脚本执行完成！"
echo "注意：如果使用国内镜像，请确保镜像源可用。实际源可根据需求调整。"
