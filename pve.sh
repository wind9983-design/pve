#!/bin/bash

# Proxmox VE 8 更换 APT 源和 CT 模板源脚本
# 作者: Grok (基于官方文档)
# 版本: 1.0
# 适用: Proxmox VE 8 (Debian Bookworm)

set -euo pipefail  # 严格模式：遇到错误退出，未定义变量报错

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'  # 无颜色

echo_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
echo_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
echo_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# 配置变量（可自定义）
BACKUP_DIR="/root/pve_sources_backup_$(date +%Y%m%d_%H%M%S)"
ENABLE_ENTERPRISE=false  # 如果有订阅，设为 true 以启用企业源
TEMPLATE_SOURCE="https://images.linuxcontainers.org"  # CT 模板源：linuxcontainers.org (或 "download.proxmox.com/images" 为官方)

# 检查是否为 Proxmox VE 8
if ! pveversion | grep -q "pve-manager/8."; then
    echo_error "此脚本仅适用于 Proxmox VE 8。请检查版本：$(pveversion)"
fi

# 创建备份目录
mkdir -p "$BACKUP_DIR"
echo_info "创建备份目录：$BACKUP_DIR"

# 1. 更换 APT 源
echo_info "开始更换 APT 源（切换到 no-subscription）..."

# 备份现有 APT 文件
cp /etc/apt/sources.list "$BACKUP_DIR/sources.list" 2>/dev/null || true
cp -r /etc/apt/sources.list.d/ "$BACKUP_DIR/sources.list.d/" 2>/dev/null || true

# 清空 sources.list（PVE 8 主要使用 sources.list.d）
echo "# Debian Bookworm repositories" > /etc/apt/sources.list
echo "deb http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware" >> /etc/apt/sources.list
echo "deb http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware" >> /etc/apt/sources.list
echo "deb http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware" >> /etc/apt/sources.list

# 禁用企业源（如果存在）
if [ -f /etc/apt/sources.list.d/pve-enterprise.list ]; then
    mv /etc/apt/sources.list.d/pve-enterprise.list "$BACKUP_DIR/pve-enterprise.list.disabled"
    echo_warn "禁用企业源：pve-enterprise.list"
fi

# 添加 no-subscription 源（deb822 格式）
cat > /etc/apt/sources.list.d/pve-no-subscription.list << EOF
Types: deb
URIs: http://download.proxmox.com/debian/pve
Suites: bookworm
Components: pve-no-subscription
Signed-By: /usr/share/keyrings/pve-archive-keyring.gpg
EOF

# 如果启用企业源（有订阅）
if [ "$ENABLE_ENTERPRISE" = true ]; then
    cat > /etc/apt/sources.list.d/pve-enterprise.list << EOF
Types: deb
URIs: https://enterprise.proxmox.com/debian/pve
Suites: bookworm
Components: pve-enterprise
Signed-By: /usr/share/keyrings/pve-archive-keyring.gpg
EOF
    echo_info "启用企业源（需订阅）"
fi

# 更新 GPG 密钥（如果缺失）
wget -qO- https://enterprise.proxmox.com/debian/proxmox-release-bookworm.gpg | tee /etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg >/dev/null || true

# 更新 APT
apt update || echo_warn "APT 更新可能有警告，请手动检查"

echo_info "APT 源更换完成。运行 'apt full-upgrade' 以应用更新。"

# 2. 更换 CT 模板源
echo_info "开始更换 CT 模板源到 $TEMPLATE_SOURCE..."

# 备份模板配置（如果存在）
if [ -f /etc/pve/.pve-iso ]; then  # 模板源通常在 /usr/share/perl5/PVE/
