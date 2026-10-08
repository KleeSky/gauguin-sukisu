#!/bin/bash
# ============================================================================
# WSL 本地编译环境搭建（Ubuntu 26.04 / WSL2）
# 用法（在 WSL 里以 root 运行）：
#   bash /mnt/c/Users/Virel/Downloads/gauguin-sukisu/scripts/wsl_setup_env.sh
# ============================================================================
set -e

export DEBIAN_FRONTEND=noninteractive

echo "=== 1/4 安装编译依赖 ==="
apt-get update -qq
apt-get install -y -qq --no-install-recommends \
    build-essential bc bison flex libssl-dev libelf-dev \
    git curl wget zip unzip python3 device-tree-compiler \
    cpio rsync lz4 zstd ccache
echo "    完成"

echo "=== 2/4 克隆内核源码（neko 树，1GB+，慢）==="
mkdir -p /root/src
cd /root/src
if [ ! -d kernel/.git ]; then
    git clone --depth=1 -b main https://github.com/Molyuu/neko_kernel_xiaomi_gauguin.git kernel
fi
echo "    内核版本："
head -n 5 kernel/Makefile | grep -E 'VERSION|PATCHLEVEL|SUBLEVEL'
ls -l kernel/arch/arm64/configs/vendor/gauguin_user_defconfig

echo "=== 3/4 克隆工具链（Proton Clang）==="
if [ ! -x tc/bin/clang ]; then
    rm -rf tc
    git clone --depth=1 https://github.com/kdrag0n/proton-clang.git tc
fi
echo "    clang 版本："
tc/bin/clang --version | head -n 2

echo "=== 4/4 环境确认 ==="
echo "    CPU 核心: $(nproc)"
df -h / | tail -n 1
echo "=== 环境搭建完成 ==="
