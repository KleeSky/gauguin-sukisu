#!/usr/bin/env python3
"""
为老内核补上 SUSFS 需要的 android_kabi_reserved* 字段（幂等）。

背景：SUSFS 的 50_add_susfs_in_kernel-4.19.patch 使用 android_kabi_reservedN
作为"私有无害 padding"来存隐藏状态，但该字段只在部分 Android/CAF 树里存在。
SUSFS 的 README 只说"需要手工补"，没给脚本，所以这里自动处理：
  - 只在 struct 体内确实缺失时才插入（避免重复成员导致编译失败）
  - 插在 struct 的左花括号之后，位置安全（不涉及嵌套花括号的解析）
用法: python3 fix_kabi.py <kernel_root>
"""
import re
import sys

TARGETS = [
    ("include/linux/sched/user.h", "user_struct", [1]),
    ("include/linux/mount.h", "vfsmount", [1, 2]),
    ("include/linux/fs.h", "inode", [1, 2]),
    ("include/linux/fs.h", "super_block", [1, 2, 3]),
    ("include/linux/sched.h", "task_struct", [3, 4]),
]


def find_struct(text, name):
    """返回 (定义起点, 左花括号下标, 右花括号下标)；找不到返回 None。"""
    for m in re.finditer(r"\bstruct\s+" + re.escape(name) + r"\s*\{", text):
        i = text.index("{", m.start())
        depth = 0
        j = i
        while j < len(text):
            c = text[j]
            if c == "{":
                depth += 1
            elif c == "}":
                depth -= 1
                if depth == 0:
                    return m.start(), i, j
            j += 1
    return None


def main(root):
    changed = 0
    for path, sname, fields in TARGETS:
        full = root.rstrip("/") + "/" + path
        try:
            with open(full) as fh:
                text = fh.read()
        except OSError:
            print("  skip (文件不存在): %s" % path)
            continue

        found = find_struct(text, sname)
        if not found:
            print("  !! 找不到 struct %s (%s)" % (sname, path))
            continue

        _, brace, end = found
        body = text[brace:end]
        missing = [n for n in fields if "android_kabi_reserved%d" % n not in body]
        if not missing:
            print("  ok   %-14s 字段已存在" % sname)
            continue

        add = "\n" + "".join("\tu64 android_kabi_reserved%d;\n" % n for n in missing).rstrip("\n")
        text = text[: brace + 1] + add + text[brace + 1 :]
        with open(full, "w") as fh:
            fh.write(text)
        changed += 1
        print("  add  %-14s +%s" % (sname, ",".join("reserved%d" % n for n in missing)))

    print("已修改 %d 个 struct" % changed)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else ".")
