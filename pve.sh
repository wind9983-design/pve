#!/bin/bash

# PVE9 CT 模板源更新脚本
# 作者: Grok (基于 Proxmox 社区实践)
# 用法: ./update-ct-templates.sh [download]  # download 参数会下载所有新模板
# 建议: 添加到 cron 中，每日运行: 0 2 * * * /path/to/update-ct-templates.sh

set -e  # 遇到错误即退出

# 日志文件
LOGFILE="/var/log/pve-ct-templates-update.log"
echo "$(date): 开始更新 CT 模板源..." >> "$LOGFILE"

# 更新模板缓存（刷新源列表）
pveam update
if [ $? -eq 0 ]; then
    echo "$(date): 模板缓存更新成功。" >> "$LOGFILE"
else
    echo "$(date): 模板缓存更新失败！" >> "$LOGFILE"
    exit 1
fi

# 可选：下载所有可用模板（默认不执行）
if [ "$1" = "download" ]; then
    echo "$(date): 开始下载所有新模板..." >> "$LOGFILE"
    pveam download local all
    if [ $? -eq 0 ]; then
        echo "$(date): 所有模板下载成功。" >> "$LOGFILE"
    else
        echo "$(date): 模板下载失败！" >> "$LOGFILE"
        exit 1
    fi
else
    echo "$(date): 未指定下载，仅更新缓存。" >> "$LOGFILE"
fi

echo "$(date): 更新完成。" >> "$LOGFILE"
