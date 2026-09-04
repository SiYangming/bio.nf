"""Snakemake wrapper for GNU sort（td2 式单任务通用规则配套，与同目录 gnu_sort.smk 契约一致）。

契约：
  - input[0]    ：输入文件（config gnu_sort_input，文本/SAM/GTF/BED 等）
  - output[0]   ：排序产物（config gnu_sort_output，默认 <输入>.sorted）
  - params.args ：透传 sort 附加参数（config gnu_sort.args，如 "-k1,1 -k4,4n"；默认空）
  - 命令        ：sort <args> <in> > <out>（stdout=排序结果重定向到输出文件，stderr 进 log；
    --parallel 由 args 自行控制，sort 自身多线程，规则不另设 threads）
  - 环境        ：exec_mode conda(默认) / docker / native；docker 用 gnu_sort.docker_image 镜像内
    sort，native 用 config gnu_sort.sort_bin，conda 走 PATH（规则无同目录 conda env，需要
    --use-conda 时由调用方自供含 coreutils 的环境）
"""

from __future__ import annotations

import os
import sys

from snakemake.shell import shell

# 注入 bioskills 共享库目录（modules/），以导入共享 docker_wrapper
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
import docker_wrapper  # noqa: E402

# stdout 是排序结果（重定向到输出文件），仅 stderr 进 log
log = snakemake.log_fmt_shell(stdout=False, stderr=True)

# Docker/native/conda 分派（docker 走镜像内默认名；native 走 config 的 sort_bin；conda 走 PATH）
docker_prefix, tool_bin = docker_wrapper.docker_wrapper_binary(
    snakemake.config,
    "gnu_sort",
    "sort_bin",
    "sort",
)

shell(f"{docker_prefix}{tool_bin} {snakemake.params.args} {snakemake.input[0]} > {snakemake.output[0]} {log}")
