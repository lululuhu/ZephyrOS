#!/usr/bin/env bash
# ============================================================================
# ZephyrOS GSI Build — Disk Optimizer
# ----------------------------------------------------------------------------
# GitHub Actions Ubuntu 22.04 运行器默认仅 ~14 GB 可用磁盘。
# 本脚本移除 AOSP 构建不需要的预装组件，释放 ~25 GB 空间。
# 移除清单（均为预装但 AOSP 构建无关的组件）：
#   - Docker Engine + 镜像  (~5 GB)
#   - .NET SDK              (~3 GB)
#   - Node.js + npm cache   (~1.5 GB)
#   - Android SDK           (~6 GB)
#   - CodeQL / hosted toolcache 缓存  (~5 GB)
#   - /usr/share/doc 与 man (~1 GB)
# ============================================================================
set -euo pipefail

echo "::group::Disk usage before cleanup"
df -h / /mnt 2>/dev/null || df -h /
echo "::endgroup::"

sudo apt-get clean -y
sudo apt-get autoremove -y --purge

# 1) 移除 Docker（AOSP 构建不需要容器运行时）
echo "[1/6] Removing Docker..."
sudo systemctl stop docker.service docker.socket 2>/dev/null || true
sudo apt-get remove -y --purge \
    docker-ce docker-ce-cli containerd.io \
    moby-engine moby-cli moby-containerd 2>/dev/null || true
sudo rm -rf /var/lib/docker /var/lib/containerd 2>/dev/null || true

# 2) 移除 .NET SDK
echo "[2/6] Removing .NET SDK..."
sudo rm -rf /usr/share/dotnet /opt/dotnet 2>/dev/null || true

# 3) 移除 Android SDK（与我们要构建的 AOSP 14 SDK 冲突且占空间）
echo "[3/6] Removing preinstalled Android SDK..."
sudo rm -rf /usr/local/lib/android/sdk 2>/dev/null || true

# 4) 移除 CodeQL 数据库与 hosted toolcache 中不需要的工具
echo "[4/6] Removing CodeQL and unused toolcache..."
sudo rm -rf /opt/hostedtoolcache/CodeQL 2>/dev/null || true
# 仅保留必要工具，移除 go / rust / haskell / ruby 多余版本
for d in /opt/hostedtoolcache/go /opt/hostedtoolcache/Rust /opt/hostedtoolcache/PyPy; do
    [ -d "$d" ] && sudo rm -rf "$d"
done

# 5) 移除 Node.js 模块缓存（保留 node 二进制供 actions 使用）
echo "[5/6] Pruning Node.js cache..."
sudo rm -rf /opt/hostedtoolcache/node/*/x64/lib/node_modules/*cache* 2>/dev/null || true
sudo npm cache clean --force 2>/dev/null || true

# 6) 清理文档与 man
echo "[6/6] Cleaning docs/man..."
sudo rm -rf /usr/share/doc /usr/share/man /usr/share/locale 2>/dev/null || true
sudo apt-get clean -y

echo "::group::Disk usage after cleanup"
df -h / /mnt 2>/dev/null || df -h /
echo "::endgroup::"

echo "[OK] Disk optimization complete."
