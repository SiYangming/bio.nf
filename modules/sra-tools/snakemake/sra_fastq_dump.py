"""Snakemake wrapper for sra-tools fastq-dump（三模式分派，与同目录 sra_fastq_dump.smk 契约一致）。

契约：
  - input.sra：输入 .sra 文件（config sra_input_sra）
  - output.dir：FASTQ 输出目录（config sra_dump_dir，内含 SE/PE 布局文件）
  - params.options：dump 选项（config sra_tools.dump_options，默认 "--split-3 --gzip"）
  - 环境：exec_mode conda(默认) / docker / native（docker 用 config sra_tools.docker_image；
    native 用 config sra_tools.fastq_dump_bin；conda 走 PATH）
"""

from __future__ import annotations

import os
import sys

from snakemake.shell import shell

# 注入 bioskills 共享库目录（modules/），以导入共享 docker_wrapper
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
import docker_wrapper  # noqa: E402

docker_prefix, tool_bin = docker_wrapper.docker_wrapper_binary(
    snakemake.config, "sra_tools", "fastq_dump_bin", "fastq-dump")

log = snakemake.log_fmt_shell(stdout=True, stderr=True)
options = snakemake.params["options"]
os.makedirs(snakemake.output.dir, exist_ok=True)
os.makedirs(os.path.dirname(os.path.abspath(str(snakemake.log))), exist_ok=True)

shell(
    "{docker_prefix}{tool_bin} {options} -O {snakemake.output.dir} {snakemake.input.sra} {log}"
)
shell("test -n \"$(ls -A {snakemake.output.dir})\"")
