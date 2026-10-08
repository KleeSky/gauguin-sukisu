#!/bin/bash
# ============================================================================
# gauguin (Redmi Note 9 Pro 5G 国行 / MIUI 14 / 4.19) KernelSU+SUSFS 本地编译
#
# 配方（全部经本地验证）：
#   内核:   Molyuu/neko_kernel_xiaomi_gauguin  (4.19.272, 面向 MIUI)
#   KSU:    tiann/KernelSU v0.9.5  ← 最后一个支持 4.19 的版本（v1.0.0 起改用 5.1+
#           SELinux 内部结构 type_val_to_struct，此树只有 type_val_to_struct_array）
#   SUSFS:  yu13140/susfs4ksu @ d3cf679  ← 52 个历史版本里能干净打上 v0.9.5 的最新一个
#   hook:   SukiSU_patch/4.19/ksu_hooks_sukisu_4.19.patch
#           （用纯 #ifdef CONFIG_KSU 保护；通用版用 CONFIG_KSU_MANUAL_HOOK，
#             而 v0.9.5 没这个开关 → 会导致 hook 静默失效）
#
# 用法: KSU_REF=v0.9.5 SUSFS_COMMIT=d3cf679 SUSFS=1 bash local_build.sh
# ============================================================================
set -e

KERNEL=${KERNEL:-/root/src/kernel}
TC=${TC:-/root/src/tc}
KSU_REF=${KSU_REF:-v0.9.5}
SUSFS_COMMIT=${SUSFS_COMMIT:-d3cf679}
SUSFS=${SUSFS:-1}
DEFCONFIG=vendor/gauguin_user_defconfig
JOBS=${JOBS:-$(nproc)}
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"

cd "$KERNEL"
export PATH="$TC/bin:$PATH"

echo "############ 0) 重置源码树到干净状态 ############"
git checkout -- . 2>/dev/null || true
rm -rf KernelSU drivers/kernelsu
git clean -fdq -e out -e .config 2>/dev/null || true
git checkout -- drivers/Makefile drivers/Kconfig 2>/dev/null || true

echo "############ 1) 写 defconfig ############"
DC="arch/arm64/configs/$DEFCONFIG"
cp "$DC" "$DC.orig"
{
    echo ""
    echo "# ---- added by local_build.sh ----"
    echo "CONFIG_KSU=y"
    echo "CONFIG_KSU_DEBUG=n"
    echo "CONFIG_KALLSYMS=y"
    # v0.9.5 的 sucompat.c 无条件引用 execve_kp 等 struct kprobe 变量 ⇒ 必须开 KPROBES。
    # 真正的 hook 走手工补丁；kprobe 注册代码稍后用 "&& 0" 关掉（SUSFS README 的做法）。
    echo "CONFIG_KPROBES=y"
    if [ "$SUSFS" = "1" ]; then
        for o in KSU_SUSFS KSU_SUSFS_SUS_PATH KSU_SUSFS_SUS_MOUNT KSU_SUSFS_SUS_KSTAT \
                 KSU_SUSFS_SPOOF_UNAME KSU_SUSFS_ENABLE_LOG KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS \
                 KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG KSU_SUSFS_OPEN_REDIRECT \
                 KSU_SUSFS_HAS_MAGIC_MOUNT KSU_SUSFS_AUTO_ADD_SUS_KSU_DEFAULT_MOUNT \
                 KSU_SUSFS_AUTO_ADD_SUS_BIND_MOUNT KSU_SUSFS_TRY_UMOUNT \
                 KSU_SUSFS_AUTO_ADD_TRY_UMOUNT_FOR_BIND_MOUNT; do
            echo "CONFIG_${o}=y"
        done
    fi
    echo "# ---- end ----"
} >> "$DC"
tail -n 6 "$DC"

echo "############ 2) 集成 KernelSU $KSU_REF ############"
curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/$KSU_REF/kernel/setup.sh" -o /tmp/ksu-setup.sh
bash /tmp/ksu-setup.sh "$KSU_REF"
test -f KernelSU/kernel/core_hook.c || { echo "!! 不是经典布局"; exit 1; }
test -f KernelSU/kernel/selinux/sepolicy.c || { echo "!! 缺 selinux"; exit 1; }
echo "KernelSU: $(cd KernelSU && git describe --tags 2>/dev/null || git rev-parse --short HEAD)"

echo "############ 3) 关闭 KSU 的 kprobe 注册（保留声明）############"
find KernelSU/kernel -type f \( -name '*.c' -o -name '*.h' \) -print0 \
  | xargs -0 sed -i \
      -e 's/^#ifdef CONFIG_KPROBES$/#if defined(CONFIG_KPROBES) \&\& 0/' \
      -e 's/^#if defined(CONFIG_KPROBES)$/#if defined(CONFIG_KPROBES) \&\& 0/'
echo "    带 '&& 0' 的位置: $(grep -rc 'CONFIG_KPROBES) && 0' KernelSU/kernel 2>/dev/null | awk -F: '{s+=$2} END {print s+0}')"

if [ "$SUSFS" = "1" ]; then
    echo "############ 4) 集成 SUSFS $SUSFS_COMMIT ############"
    if [ ! -d /root/src/susfs/.git ]; then
        git clone -q https://github.com/yu13140/susfs4ksu.git /root/src/susfs
    fi
    ( cd /root/src/susfs && git checkout -q "$SUSFS_COMMIT" && \
      echo "    SUSFS: $(git log -1 --format='%h %ad' --date=short)" )

    cp -f /root/src/susfs/kernel_patches/fs/* fs/
    cp -f /root/src/susfs/kernel_patches/include/linux/* include/linux/
    # sus_su.h 里写着 #include "../../drivers/kernelsu/sucompat.h"
    cp -f /root/src/susfs/kernel_patches/KernelSU/kernel/sucompat.h KernelSU/kernel/sucompat.h

    echo "    -- 内核侧补丁 50_add_susfs_in_kernel-4.19.patch"
    cp -f /root/src/susfs/kernel_patches/50_add_susfs_in_kernel-4.19.patch ./
    patch -p1 --forward < 50_add_susfs_in_kernel-4.19.patch || true
    echo "    -- KSU 侧补丁 10_enable_susfs_for_ksu.patch"
    cp -f /root/src/susfs/kernel_patches/KernelSU/10_enable_susfs_for_ksu.patch ./KernelSU/
    ( cd KernelSU && patch -p1 --forward < 10_enable_susfs_for_ksu.patch || true )
    echo "    .rej 文件："
    find . -name '*.rej' -not -path './out/*' 2>/dev/null | head -n 20 || true

    echo "    -- 补 android_kabi_reserved* 字段"
    python3 "$SELF_DIR/fix_kabi.py" "$KERNEL"
fi

echo "############ 5) 打 non-GKI 手工 hook 补丁 ############"
curl -LSs "https://raw.githubusercontent.com/SukiSU-Ultra/SukiSU_patch/main/4.19/ksu_hooks_sukisu_4.19.patch" -o /tmp/ksu_hooks.patch
if patch -p1 --forward < /tmp/ksu_hooks.patch && ! find . -name '*.rej' -not -path './out/*' | grep -q .; then
    echo "    方案 A 成功"
else
    echo "    方案 A 失败，改用方案 B（sed 版）"
    git checkout -- fs/exec.c fs/open.c fs/read_write.c fs/stat.c drivers/input/input.c drivers/tty/pty.c
    find . -name '*.rej' -not -path './out/*' -delete
    curl -LSs "https://raw.githubusercontent.com/JackA1ltman/NonGKI_Kernel_Build/old-v1/Patches/syscall_hook_patches.sh" -o /tmp/bs.sh
    bash /tmp/bs.sh
fi
grep -c ksu_handle_execveat fs/exec.c

echo "############ 6) MODULE_IMPORT_NS 兼容宏 ############"
if ! grep -q "define MODULE_IMPORT_NS" include/linux/module.h; then
    {
        echo ""
        echo "#ifndef MODULE_IMPORT_NS"
        echo "#include <linux/stringify.h>"
        echo "#define MODULE_IMPORT_NS(ns) MODULE_INFO(import_ns, __stringify(ns))"
        echo "#endif"
    } >> include/linux/module.h
    echo "    已注入"
else
    echo "    已存在"
fi

echo "############ 7) 编译 ############"
MAKE_ARGS="O=out ARCH=arm64 CC=clang CROSS_COMPILE=aarch64-linux-gnu- \
CROSS_COMPILE_COMPAT=arm-linux-gnueabi- CLANG_TRIPLE=aarch64-linux-gnu- OBJDUMP=llvm-objdump"

make $MAKE_ARGS "$DEFCONFIG"
echo "--- 生效的关键配置 ---"
grep -E '^CONFIG_(KSU|KALLSYMS|KPROBES|OVERLAY_FS)' out/.config || true
grep -E '^# CONFIG_(KSU|KPROBES)' out/.config || true

echo "--- 开始编译 ($JOBS 线程) ---"
set -o pipefail
make -k -j"$JOBS" $MAKE_ARGS 2>&1 | tee /root/build.log
echo "--- 产物 ---"
ls -lh out/arch/arm64/boot/Image out/arch/arm64/boot/dtbo.img 2>/dev/null || echo "没有 Image"
