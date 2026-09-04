"""Snakemake wrapper for samtools index（通用单任务规则配套，与同目录 samtools_index.smk 契约一致）。

契约：
  - input.bam：sorted BAM（config samtools_index_input，也可为 CRAM）
  - output.bai：索引文件（config samtools_index_output，默认 <输入>.bai）
  - params.extra：透传 index 附加参数（config samtools.index_extra_params，如 "-c" 生成 .csi；
    此时请自行指定输出名）
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


extra = snakemake.params.get("extra", "")
log = snakemake.log_fmt_shell(stdout=True, stderr=True)

# Docker/native/conda 分派（docker 走镜像内默认名；native 走 config 的 samtools_bin；conda 走 PATH）
docker_prefix, tool_bin = docker_wrapper.docker_wrapper_binary(
    snakemake.config,
    "samtools",
    "samtools_bin",
    "samtools",
)

# 线程：samtools index 的 -@ 为额外线程数（主线程 1 + threads-1）
threads = "" if snakemake.threads <= 1 else " -@ {}".format(snakemake.threads - 1)

shell(
    "{docker_prefix}{tool_bin} index"
    "{threads}"
    " {extra}"
    " {snakemake.input.bam}"
    " {snakemake.output.bai}"
    " {log}"
)
