# 01 · GitHub Actions 云端编译 —— 逐步操作说明

> 你没用过 Actions，所以这份文档是"点哪里"级别的。全程只需要浏览器 + 一个命令行窗口。
> 编译在 GitHub 的服务器上跑，**你的电脑不用装 Linux，也不用 100GB 空间**。

---

## 0. 先看清你要上传的东西

我已经在 `C:\Users\Virel\Downloads\gauguin-sukisu\` 里准备好了这个结构：

```
gauguin-sukisu\
├── .github\
│   └── workflows\
│       └── build-gauguin-sukisu.yml     ← 编译脚本（唯一的必需文件）
├── 00-准备工作清单.md
├── 01-GitHub-Actions-逐步操作说明.md      ← 本文档
├── 02-刷入与救砖说明.md
└── stock\
    └── boot.img                          ← 需要你自己放进去（见第 6 步）
```

`.github` 是**隐藏文件夹**（名字以点开头）。在文件资源管理器里勾选
「查看 → 显示 → 隐藏的项目」才看得见，否则复制/上传时容易漏掉它。

---

## 1. 在 GitHub 上新建仓库

1. 打开 https://github.com/new
2. 填写：
   - **Repository name**：`gauguin-sukisu`（随便起，记住就行）
   - **Description**：随便
   - **Public** ← **强烈建议选公开**。私有仓库的 Actions 每月只有 2000 分钟免费额度，内核编译一次要 30~60 分钟，来回调几次就用光了；公开仓库不计额度。
   - **不要**勾选 "Add a README file"（我们只要空仓库）
3. 点 **Create repository**
4. 创建完的页面上会显示仓库地址，形如：
   `https://github.com/你的用户名/gauguin-sukisu.git`
   **把这个地址记下来。**

---

## 2. 把文件推上去（推荐方式 A：命令行）

你电脑上已经装了 Git（`D:\Program Files\Git\cmd\git.exe`）。

打开 **PowerShell**，**原样**执行下面这几行（你的用户名 `KleeSky` 我已经填好了）：

```powershell
cd C:\Users\Virel\Downloads\gauguin-sukisu

git init -b main
git add .
git commit -m "gauguin SukiSU-Ultra build"

git remote add origin https://github.com/KleeSky/gauguin-sukisu.git
git push -u origin main
```

第一次 `git push` 时会弹出一个浏览器窗口让你登录 GitHub 授权（Git Credential Manager），点同意就行。

> 如果提示 `remote origin already exists`，说明你重复执行了，改成：
> `git remote set-url origin https://github.com/KleeSky/gauguin-sukisu.git`

### 方式 B：不想用命令行，用浏览器上传

1. 在新仓库页面点 **Add file → Create new file**
2. 文件名框里**直接输入带斜杠的完整路径**（GitHub 会自动建目录）：
   `.github/workflows/build-gauguin-sukisu.yml`
3. 把本地 `build-gauguin-sukisu.yml` 的全部内容贴进编辑框
4. 拉到底点 **Commit changes**

（这种方式要复制 300 多行 YAML，容易出错或漏行，所以还是推荐方式 A。）

---

## 3. 确认 Actions 是开着的

进你的仓库 → 顶部 **Actions** 标签页：

- 如果是**空白页或提示让你启用**，点绿色按钮 **"I understand my workflows, go ahead and enable them"**
- 左侧列表里应该能看到 **"Build SukiSU-Ultra kernel for gauguin (Redmi Note 9 Pro 5G / MIUI 14 / A12)"**

---

## 4. 先做一次"不带 boot.img"的试编译（可选但建议）

这一步的意义：**先确认内核能编出来**，再去折腾 boot.img 重打包。第一次跑几乎肯定会暴露一些需要我修的问题，先把问题暴露在便宜的地方。

### 怎么跑

1. Actions 标签页 → 左侧点那个 workflow
2. 右上角 **Run workflow** 下拉 → 填参数 → **Run workflow**（绿色按钮）

参数就按这个填：

| 参数 | 填什么 | 说明 |
|---|---|---|
| `kernel_repo` | 默认值不动 | 用 Molyuu 的 neko 树（面向 MIUI，含小米私有相机驱动） |
| `kernel_branch` | 默认值不动 | `main` |
| `ksu_ref` | **`v3.2.0`** | ⚠️ 必须是经典 KernelSU 布局的 `v3.2.0`。`main`/`v4.2.0` 是 5.10+ 的新布局，在 4.19 上会报**几百个错**（SELinux 内部结构等），已实测。workflow 里有布局预检查，选错会 30 秒内报错 |
| `susfs` | **`true`** | v3.2.0 的文件布局正好是 SUSFS 官方 4.19 补丁的目标，**这次 SUSFS 能打上**。如果补丁报 `.rej` 失败，重跑时选 `false` 先拿 root |
| `kpm` | **第一次选 `false`** | 实验性，等第一版确认能开机再加 |
| `toolchain` | `proton-clang` | 3 个选项，按这个顺序试：`proton-clang` → `aosp-clang15` → `aosp-r383902`。失败一次就换下一个重跑，**不用改文件，只改这个下拉框** |

3. 等 30~60 分钟。页面会实时显示日志。

### 成功了会看到什么

跑完后点进那次运行，页面底部 **Artifacts** 区域会出现一个 `gauguin-sukisu-build`，点它下载 zip，里面有：

- `Image`、`dtb`、`dtbo.img` —— 内核产物
- `gauguin-SukiSU-AnyKernel3.zip` —— 给 recovery 用的刷机包（你暂时用不上，留着）
- `boot-new.img` —— **只有放了 `stock/boot.img` 才会有**（见第 6 步）
- `error.log`、`*.rej` —— 只有出问题时才有，用来给我排查

### 失败了怎么办

把下面两样东西发我：

1. **失败了哪一步**（日志里红色的那一步的名字）
2. 那一步的日志内容（从 `Run` 那行开始往下复制），或者直接下载 artifact 里的 `error.log`

---

## 5. 确认产物正常（我会帮你看）

正常的话，这次运行日志里应该能看到类似：

```
-- KERNEL_TYPE: Non-GKI
-- SukiSU-Ultra: using SUSFS_INLINE_HOOK
-- SUSFS_VERSION: v1.5.x
...
==> 本次构建实际生效的关键配置：
CONFIG_KSU=y
CONFIG_KSU_SUSFS=y
CONFIG_KALLSYMS=y
```

**如果 `CONFIG_KSU=y` 没出现**，或者 `--- 残留的 .rej` 列出了一些文件，把汇总那段发我。

---

## 5.5 workflow 内置的容错（你会从日志里看到这些）

我在编译脚本里预埋了 5 道防线，目的是"**第一次就尽量跑出能刷的东西**"，而不是一有小问题就整体失败：

| 防线 | 行为 | 日志关键词 |
|---|---|---|
| hook 补丁双方案 | 先用 SukiSU 官方 4.19 补丁；失败就自动回滚并改用 backslashxx 的 syscall hook 脚本 | `方案 A 成功` / `改用方案 B` |
| SUSFS 优雅降级 | SUSFS 补丁打不上时**自动降级**为"只有 SukiSU root"，并且不回滚已经打好的 hook 补丁 | `自动降级` / `SUSFS_OK=false` |
| CONFIG_KSU 闸门 | `.config` 里没有 `CONFIG_KSU=y` → **立刻失败**，不浪费 40 分钟编一个没 root 的内核 | `这个内核将完全没有 root` |
| dtb 安全闸门 | 拼接出的 dtb 是空的 → **终止且不上传**，因为那种镜像刷进去会黑屏 | `几乎肯定是没找到 .dtb 文件` |
| boot.img 重打包双方案 | 先试 AOSP `mkbootimg`（3 个候选分支）；不行就用 Magisk APK 里的 `magiskboot`（和 AnyKernel3 在手机上用的是同一个工具） | `方案 A 可用` / `改用方案 B：magiskboot` |

> 降级不是坏事：**先拿到一个能开机、有 root 的内核**，再单独攻克 SUSFS / KPM。这样万一出问题，你能明确知道是哪一层的原因。

---

## 6. 加入原厂 boot.img（这样才能 fastboot 刷入）

你没有 recovery，所以必须把新内核和**原厂 ramdisk** 重新打包成 boot.img。这一步需要你从官方线刷包里拿 `boot.img`：

1. 解出 `boot.img`（解包方法见 <kbd>00-准备工作清单.md</kbd> 第一节）
2. 在本地文件夹里建子目录并放进去：
   ```powershell
   mkdir C:\Users\Virel\Downloads\gauguin-sukisu\stock
   copy <你的boot.img路径> C:\Users\Virel\Downloads\gauguin-sukisu\stock\boot.img
   ```
3. 再推一次：
   ```powershell
   cd C:\Users\Virel\Downloads\gauguin-sukisu
   git add stock/boot.img
   git commit -m "add stock boot.img"
   git push
   ```
   > 如果 push 时提示文件超过 50MB，只是**警告**，等一会儿会继续；超过 100MB 才会被拒（gauguin 的 boot.img 大约 60~90MB，正常不会超）。

4. 回 Actions **再跑一次**同样的 workflow。这次的产物里就会多出 **`boot-new.img`** —— 这是你真正要刷的文件。

---

## 7. 产物清单（最终你会拿到）

| 文件 | 用途 |
|---|---|
| **`boot-new.img`** | ⭐ 主力：`fastboot flash boot boot-new.img` |
| **`dtbo.img`** | ⭐ 一起刷：`fastboot flash dtbo dtbo.img` |
| `gauguin-SukiSU-AnyKernel3.zip` | 备用：以后装了 TWRP 可以直接刷这个 |
| `Image` / `dtb` | 原始产物，出问题时用来分析 |

拿到 `boot-new.img` 和 `dtbo.img` 后，去看 <kbd>02-刷入与救砖说明.md</kbd>。

---

## 8. 可能踩的坑（提前告诉你）

| 现象 | 原因 | 处理 |
|---|---|---|
| 构建到 `编译` 步骤失败，报 clang 相关错误 | 工具链和这个 4.19 树不匹配 | 按 `proton-clang` → `aosp-clang15` → `aosp-r383902` 顺序换着重跑；日志里 `工具链实际版本` 那几行发我 |
| 有 `.rej` 文件但编译过了 | 某个补丁没完全打上 | 把 `.rej` 内容发我，多半是 SUSFS 补丁版本漂移 |
| `CONFIG_KSU_SUSFS` 没出现在生效配置里 | builtin 分支的 Kconfig 选项名和 SUSFS 补丁版本对不上 | 发我 `out/.config` 里 KSU 相关的行 |
| Actions 跑了 6 小时被取消 | 默认超时 | 我在 workflow 里设了 180 分钟；超时说明卡住了，发我日志 |
| 私有仓库 Actions 额度耗尽 | 私有仓库计费 | 把仓库改成 public |
