#!/bin/bash
# WSL 里跑本地编译，并把噪声过滤掉，只留关键信息
cd /root/src || exit 1

KSU_REF=${KSU_REF:-v0.9.5} \
SUSFS_COMMIT=${SUSFS_COMMIT:-d3cf679} \
SUSFS=${SUSFS:-1} \
bash /mnt/c/Users/Virel/Downloads/gauguin-sukisu/scripts/local_build.sh > /root/local_build.log 2>&1
RC=$?

echo "================ 编译结束 EXIT=$RC ================"
echo ""
echo "=== 各阶段标记（看走到哪一步） ==="
grep -E '^############' /root/local_build.log || true
echo ""
echo "=== 编译错误（去重，前 60 条）==="
grep -hE 'error:|fatal error:' /root/local_build.log | sed 's/^[[:space:]]*//' | sort -u | head -n 60 || true
echo ""
echo "=== 残留 .rej ==="
find /root/src/kernel -name '*.rej' -not -path '*/out/*' 2>/dev/null | head -n 20 || true
echo ""
echo "=== 产物 ==="
ls -lh /root/src/kernel/out/arch/arm64/boot/Image 2>/dev/null || echo "(没有 Image)"
echo ""
echo "=== 关键配置 ==="
grep -E '^CONFIG_(KSU|KALLSYMS|KPROBES|OVERLAY_FS)' /root/src/kernel/out/.config 2>/dev/null | head -n 12 || true
