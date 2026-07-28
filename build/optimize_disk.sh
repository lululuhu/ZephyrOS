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
echo "[1/8] Removing Docker..."
sudo systemctl stop docker.service docker.socket 2>/dev/null || true
sudo apt-get remove -y --purge \
    docker-ce docker-ce-cli containerd.io \
    moby-engine moby-cli moby-containerd 2>/dev/null || true
sudo rm -rf /var/lib/docker /var/lib/containerd 2>/dev/null || true

# 2) 移除 .NET SDK
echo "[2/8] Removing .NET SDK..."
sudo rm -rf /usr/share/dotnet /opt/dotnet 2>/dev/null || true

# 3) 移除 Android SDK（与我们要构建的 AOSP SDK 冲突且占空间）
echo "[3/8] Removing preinstalled Android SDK..."
sudo rm -rf /usr/local/lib/android/sdk 2>/dev/null || true
sudo rm -rf /usr/local/lib/android 2>/dev/null || true

# 4) 移除 CodeQL 数据库与 hosted toolcache 中不需要的工具
echo "[4/8] Removing CodeQL and unused toolcache..."
sudo rm -rf /opt/hostedtoolcache/CodeQL 2>/dev/null || true
# 删除整个 hostedtoolcache (保留 node 供 actions 使用)
for d in /opt/hostedtoolcache/go /opt/hostedtoolcache/Rust /opt/hostedtoolcache/PyPy \
         /opt/hostedtoolcache/Java /opt/hostedtoolcache/Ruby /opt/hostedtoolcache/Python \
         /opt/hostedtoolcache/haskell /opt/hostedtoolcache/stack; do
    [ -d "$d" ] && sudo rm -rf "$d"
done

# 5) 移除 Node.js 模块缓存（保留 node 二进制供 actions 使用）
echo "[5/8] Pruning Node.js cache..."
sudo rm -rf /opt/hostedtoolcache/node/*/x64/lib/node_modules/*cache* 2>/dev/null || true
sudo npm cache clean --force 2>/dev/null || true

# 6) 清理文档与 man
echo "[6/8] Cleaning docs/man..."
sudo rm -rf /usr/share/doc /usr/share/man /usr/share/locale 2>/dev/null || true
sudo apt-get clean -y

# 7) 激进清理: 删除预装语言运行时和大目录 (AOSP 自带所有需要的工具链)
echo "[7/8] Aggressive cleanup of preinstalled runtimes..."
sudo rm -rf /usr/local/lib/node_modules 2>/dev/null || true
sudo rm -rf /usr/local/share/gradle 2>/dev/null || true
sudo rm -rf /usr/local/lib/android 2>/dev/null || true
sudo rm -rf /usr/lib/jvm 2>/dev/null || true  # AOSP 自带 OpenJDK
sudo rm -rf /var/cache/apt 2>/dev/null || true
sudo rm -rf /var/lib/apt/lists 2>/dev/null || true
sudo rm -rf /var/cache/pip 2>/dev/null || true
sudo rm -rf /home/runner/.cache 2>/dev/null || true
sudo rm -rf /home/runner/.gradle 2>/dev/null || true
sudo rm -rf /home/runner/.m2 2>/dev/null || true
sudo rm -rf /home/runner/.npm 2>/dev/null || true
sudo rm -rf /home/runner/.rustup 2>/dev/null || true
sudo rm -rf /home/runner/.cargo 2>/dev/null || true
# 清理 snap (如果存在)
sudo rm -rf /snap 2>/dev/null || true
sudo rm -rf /var/snap 2>/dev/null || true
# 清理多余的 Python 包
sudo rm -rf /usr/local/lib/python* 2>/dev/null || true
sudo rm -rf /usr/local/lib/pypy* 2>/dev/null || true

# 8) 清理 /tmp 和日志
echo "[8/8] Cleaning /tmp and logs..."
sudo rm -rf /tmp/* 2>/dev/null || true
sudo journalctl --vacuum-size=1M 2>/dev/null || true
sudo apt-get clean -y
sudo apt-get autoremove -y --purge 2>/dev/null || true

echo "::group::Disk usage after cleanup"
df -h / /mnt 2>/dev/null || df -h /
echo "::endgroup::"

echo "[OK] Disk optimization complete."
