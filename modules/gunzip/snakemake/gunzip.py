"""Snakemake wrapper for gunzip（td2 式单任务通用规则配套，与同目录 gunzip.smk 契约一致）。

契约：
  - input[0]  ：.gz 压缩文件（config gunzip_input）
  - output[0] ：解压明文产物（config gunzip_output，默认 <输入去 .gz 后缀>）
  - 命令      ：gzip -cd <in.gz> > <out>（stdout=解压内容重定向到输出文件，stderr 进 log）
  - 环境      ：exec_mode conda(默认) / docker / native；docker 用 gunzip.docker_image 镜像内
    gzip，native 用 config gunzip.gzip_bin，conda 走 PATH（规则无同目录 conda env，需要
    --use-conda 时由调用方自供含 gzip 的环境）
"""

from __future__ import annotations

import os
import sys

from snakemake.shell import shell

# 注入 bioskills 共享库目录（modules/），以导入共享 docker_wrapper
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
import docker_wrapper  # noqa: E402

# stdout 是解压内容（重定向到输出文件），仅 stderr 进 log
log = snakemake.log_fmt_shell(stdout=False, stderr=True)

# Docker/native/conda 分派（docker 走镜像内默认名；native 走 config 的 gzip_bin；conda 走 PATH）
docker_prefix, tool_bin = docker_wrapper.docker_wrapper_binary(
    snakemake.config,
    "gunzip",
    "gzip_bin",
    "gzip",
)

shell(f"{docker_prefix}{tool_bin} -cd {snakemake.input[0]} > {snakemake.output[0]} {log}")
