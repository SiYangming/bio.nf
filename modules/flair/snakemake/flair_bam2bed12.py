"""Snakemake wrapper for flair bam2bed12（通用单任务规则配套，与同目录 flair_bam2bed12.smk 契约一致）。

语义：sorted BAM -> BED12。实现走 bedtools bamtobed -bed12 + 同目录 helper
bed12_add_trailing_commas.py 的尾逗号修复管道（helper 经 Path(__file__).parent
同目录定位），与 FLAIR 官方 bam2Bed12 输出格式等价（原聚合 flair.smk rule
bam2bed12 的 shell 内联管道迁入本 wrapper）。

契约：
  - input.bam：sorted BAM（config flair_bam2bed12_input）
  - output.bed12：BED12（config flair_bam2bed12_output）
  - 环境：exec_mode conda(默认) / docker / native；docker 用镜像内 bedtools（需
    含 bedtools 的镜像，如官方 flair 镜像），native 用 config flair.bedtools_bin，
    conda 走 PATH（flair.yaml 含 bedtools）
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

from snakemake.shell import shell

# 注入 bioskills 共享库目录（modules/），以导入共享 docker_wrapper
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
import docker_wrapper  # noqa: E402

log = snakemake.log_fmt_shell(stdout=False, stderr=True)

# Docker/native/conda 分派（bedtools 为实际被调二进制）
docker_prefix, tool_bin = docker_wrapper.docker_wrapper_binary(
    snakemake.config,
    "flair",
    "bedtools_bin",
    "bedtools",
)

out_file = str(snakemake.output.bed12)
out_dir = os.path.dirname(out_file)
if out_dir and not os.path.exists(out_dir):
    os.makedirs(out_dir)

# helper 与 wrapper 平铺同目录（td2 式布局）
helper = Path(__file__).resolve().parent / "bed12_add_trailing_commas.py"

shell(
    f"{docker_prefix}{tool_bin} bamtobed -bed12 -i {snakemake.input.bam}"
    f" | {sys.executable} {helper} > {out_file}{log}"
)
