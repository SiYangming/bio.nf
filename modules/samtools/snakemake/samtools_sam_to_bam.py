"""Snakemake wrapper for samtools sam->bam（通用单任务规则配套，与同目录 samtools_sam_to_bam.smk 契约一致）。

契约：
  - input.sam：输入 SAM（config samtools_sam_to_bam_input）
  - output.bam：输出 BAM（config samtools_sam_to_bam_output，默认 <输入去扩展名>.bam；
    temp 中间产物，被下游消费后自动清理）
  - 命令：固定 `samtools view -b`（SAM -> BAM 格式转换，无过滤）
  - threads：规则调度线程（-@ 取 threads-1）
  - 环境：exec_mode conda(默认) / docker / native；docker 用镜像内 samtools（config
    samtools.docker_image），native 用 config samtools.samtools_bin，conda 走 PATH
"""

from __future__ import annotations

__author__ = "Yangming Si"
__copyright__ = "Copyright 2026, Yangming Si"
__email__ = "siyangming1991@163.com"
__license__ = "MIT"

import os
import sys

from snakemake.shell import shell

# 注入 bioskills 共享库目录（modules/），以导入共享 docker_wrapper
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
import docker_wrapper  # noqa: E402


log = snakemake.log_fmt_shell(stdout=True, stderr=True)

# Docker/native/conda 分派（docker 走镜像内默认名；native 走 config 的 samtools_bin；conda 走 PATH）
docker_prefix, tool_bin = docker_wrapper.docker_wrapper_binary(
    snakemake.config,
    "samtools",
    "samtools_bin",
    "samtools",
)

# 线程：samtools view 的 -@ 为额外线程数（主线程 1 + threads-1）
threads = "" if snakemake.threads <= 1 else " -@ {}".format(snakemake.threads - 1)

shell(
    "{docker_prefix}{tool_bin} view -b"
    "{threads}"
    " {snakemake.input.sam}"
    " -o {snakemake.output.bam}"
    " {log}"
)
