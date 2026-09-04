"""TAMA 脚本解析 helper：内置 -> 用户缓存（首次从 GitHub 远程 raw 下载）-> PATH。

背景：gs-tama 源码（python3 fork: https://github.com/SiYangming/gs-tama，默认分支 master）
不随本仓库捆绑（modules/gstama/native/ 不内置 gs-tama-1.0.4 目录，仓库保持轻量）。

解析链（供 gs_tama.py / tama_polyacleanup.py 使用）：
  1) 显式指定路径（存在即用；指定但不存在时给出提示并继续）
  2) 模块内置 modules/gstama/native/gs-tama-1.0.4/<rel>（若日后内置）
  3) 用户缓存 ~/.cache/bioskills/gs-tama/<rel>；首次缺失时从
     https://raw.githubusercontent.com/SiYangming/gs-tama/master/<rel> 下载并复用（之后可离线）
  4) 以上均不可用时返回空 Path()，由调用方回退到 PATH 中查找脚本名

注意：远程脚本为自包含单文件（仅依赖 biopython；collapse 处理 BAM 时另需 pysam），
因此单文件即可运行，无需拉取整个 gs-tama 仓库。
"""
from __future__ import annotations

import os
import sys
import urllib.request
from pathlib import Path

GS_TAMA_RAW = "https://raw.githubusercontent.com/SiYangming/gs-tama/master"
CACHE_ROOT = Path(os.environ.get("BIOSKILLS_CACHE", Path.home() / ".cache" / "bioskills")) / "gs-tama"


def _builtin_path(rel: str) -> Path:
    # 本文件与 gs_tama.py / tama_polyacleanup.py 同目录（modules/gstama/native/）
    return Path(__file__).resolve().parent / "gs-tama-1.0.4" / rel


def _download_to_cache(rel: str) -> Path:
    """从远程 raw 下载单脚本到用户缓存目录（幂等；失败抛错由调用方兜底）。"""
    cached = CACHE_ROOT / rel
    url = f"{GS_TAMA_RAW}/{rel}"
    CACHE_ROOT.mkdir(parents=True, exist_ok=True)
    print(f"[INFO] 下载 gs-tama 脚本到用户缓存:\n       {url}\n       -> {cached}", file=sys.stderr)
    urllib.request.urlretrieve(url, cached)
    if not cached.is_file() or cached.stat().st_size == 0:
        raise RuntimeError(f"下载结果为空或不可读: {cached}")
    print(f"[INFO] gs-tama 脚本已就绪: {cached}", file=sys.stderr)
    return cached


def resolve_tama_script(rel: str, explicit: str | None = None) -> Path:
    """按解析链返回 TAMA 脚本绝对路径；全部失败返回空 Path()（调用方回退 PATH）。"""
    if explicit:
        p = Path(os.path.expanduser(explicit))
        if p.is_file():
            return p
        print(f"[WARN] 显式指定的 TAMA 脚本不存在: {explicit}；按内置/缓存/远程/PATH 继续尝试",
              file=sys.stderr)

    builtin = _builtin_path(rel)
    if builtin.is_file():
        return builtin

    cached = CACHE_ROOT / rel
    if cached.is_file():
        return cached

    # 远程下载一次并缓存复用（失败仅告警，由调用方回退 PATH）
    try:
        return _download_to_cache(rel)
    except Exception as exc:  # noqa: BLE001 - 网络/权限等任一失败都降级处理
        print(f"[WARN] gs-tama 远程下载失败（{exc}）；将回退到 PATH 查找 {Path(rel).name}",
              file=sys.stderr)
        return Path()


if __name__ == "__main__":
    # 手动调试：python3 tama_remote.py tama_merge.py
    rel = sys.argv[1] if len(sys.argv) > 1 else "tama_merge.py"
    p = resolve_tama_script(rel)
    print(f"resolved: {p}" if p.is_file() else f"未找到 {rel}（可检查网络/缓存）")
