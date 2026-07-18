#!/usr/bin/env bash
# ============================================================================
# ZephyrOS — One-Click Push to GitHub
# ----------------------------------------------------------------------------
# 用法 (在 Linux/Mac/WSL 终端执行):
#   1. 修改下面的 GITHUB_URL 为你的仓库地址
#   2. 运行: bash push_to_github.sh
#
# 第一次运行会让你登录 GitHub (按提示操作)
# 之后会自动 push 所有代码并触发 GSI 构建
# ============================================================================
set -e

# ============ 修改这一行为你的 GitHub 仓库地址 ============
GITHUB_URL="https://github.com/你的用户名/ZephyrOS.git"
# ========================================================

echo "=========================================="
echo "  ZephyrOS — One-Click Push to GitHub"
echo "=========================================="
echo ""
echo "Target: $GITHUB_URL"
echo ""

# 1. 检查 git 是否安装
if ! command -v git >/dev/null 2>&1; then
    echo "[ERROR] git not installed. Install it first:"
    echo "  Ubuntu/WSL: sudo apt install git"
    echo "  Mac: brew install git"
    exit 1
fi

# 2. 检查是否已在仓库目录
if [ ! -d ".git" ]; then
    echo "[ERROR] 请在 ZephyrOS 项目根目录运行此脚本"
    echo "        (即包含 .github/ 和 vendor/ 的目录)"
    exit 1
fi

# 3. 配置 git (如果未配置)
if [ -z "$(git config user.name)" ]; then
    git config user.name "ZephyrOS Builder"
    git config user.email "builder@zephyros.local"
    echo "[OK] git configured"
fi

# 4. 添加 remote (如果不存在)
if ! git remote get-url origin >/dev/null 2>&1; then
    echo "[INFO] Adding remote: $GITHUB_URL"
    git remote add origin "$GITHUB_URL"
else
    echo "[INFO] Updating remote URL"
    git remote set-url origin "$GITHUB_URL"
fi

# 5. 提交所有变更
echo "[INFO] Staging files..."
git add -A
if git diff --cached --quiet; then
    echo "[INFO] No new changes to commit"
else
    git commit -m "ZephyrOS update $(date +%Y-%m-%d)"
    echo "[OK] Changes committed"
fi

# 6. Push
echo ""
echo "[INFO] Pushing to GitHub..."
echo "       (首次可能需要输入 GitHub 用户名和 Personal Access Token)"
echo "       Token 生成: https://github.com/settings/tokens (勾选 repo 权限)"
echo ""
git push -u origin main || git push -u origin master

echo ""
echo "=========================================="
echo "  Push 完成!"
echo "=========================================="
echo ""
echo "下一步:"
echo "  1. 打开浏览器访问你的 GitHub 仓库"
echo "  2. 点击 'Actions' 标签"
echo "  3. 在左侧找到 'Build ZephyrOS GSI'"
echo "  4. 点击右侧 'Run workflow' 按钮"
echo "  5. 等待 4-5 小时"
echo "  6. 完成后在构建详情页 'Artifacts' 下载 system.img"
echo ""
echo "刷入设备:"
echo "  fastboot flash system system.img"
echo "  fastboot reboot"
echo ""
