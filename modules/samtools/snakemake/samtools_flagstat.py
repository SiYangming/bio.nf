"""Snakemake wrapper for samtools flagstat（通用单任务规则配套，与同目录 samtools_flagstat.smk 契约一致）。

契约：
  - input.bam：输入 BAM/CRAM（config samtools_flagstat_input）
  - output.txt：统计文本（config samtools_flagstat_output，默认 <输入去扩展名>.flagstat.txt）
  - 命令：`samtools flagstat {input} > {output}`（无额外参数/线程；flagstat 结果写 stdout，
    故 stdout 重定向到 output，log 只收 stderr——与原 shell 语义一致）
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


# flagstat 结果写 {output}（stdout），log 仅收 stderr；不可用 stdout=True 的 log_fmt（会把
# 主输出重定向进 log，导致 output 为空文件）
log = snakemake.log_fmt_shell(stdout=False, stderr=True)

# Docker/native/conda 分派（docker 走镜像内默认名；native 走 config 的 samtools_bin；conda 走 PATH）
docker_prefix, tool_bin = docker_wrapper.docker_wrapper_binary(
    snakemake.config,
    "samtools",
    "samtools_bin",
    "samtools",
)

shell(
    "{docker_prefix}{tool_bin} flagstat"
    " {snakemake.input.bam}"
    " > {snakemake.output.txt}"
    " {log}"
)
