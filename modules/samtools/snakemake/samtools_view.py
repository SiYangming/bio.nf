"""Snakemake wrapper for samtools view（通用单任务规则配套，与同目录 samtools_view.smk 契约一致）。

契约：
  - input.bam：输入 BAM/SAM/CRAM（config samtools_view_input）
  - output.out：过滤/转换后输出（config samtools_view_output，默认 <输入去扩展名>_view.bam；
    输出格式按扩展名推断）
  - params.extra：透传 view 附加参数（config samtools.view_extra_params，如 "-F 1796 -q 30 -b"；
    勿重复传 -o）
  - params.region：可选区域字符串（config samtools_view_region，如 "chr1:1000-2000"；空则全文件）
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
region = snakemake.params.get("region", "")
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
    "{docker_prefix}{tool_bin} view"
    "{threads}"
    " {extra}"
    " {snakemake.input.bam}"
    " {region}"
    " -o {snakemake.output.out}"
    " {log}"
)
