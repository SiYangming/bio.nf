"""Snakemake wrapper for ORFfinder（td2 式 config 驱动规则配套）。

契约（与同目录 orffinder.smk 一致）：
  - input.fasta：输入核酸 FASTA（config orffinder_input_fasta；.gz 时自动解压到执行目录）
  - output.file：ORF 预测结果（config orffinder_outdir/<fasta_stem><suffix>）
  - params.outfmt / params.extra：输出格式与透传（config orffinder.outfmt / extra_params）
  - 环境：exec_mode conda(默认)/docker/native；native 用 orffinder.orffinder_bin，conda/docker 走 PATH 或镜像
"""

from __future__ import annotations

import os
import sys
from os.path import dirname, exists

from snakemake.shell import shell

# 注入 bioskills 共享库目录（modules/），以导入共享 docker_wrapper
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
import docker_wrapper  # noqa: E402

outfmt = int(snakemake.params["outfmt"])
extra = str(snakemake.params["extra"])
log_file = str(snakemake.log)
log_dir = dirname(log_file)
if log_dir:
    os.makedirs(log_dir, exist_ok=True)

# Docker/二进制解析：docker 用镜像内默认名；native 用 config 的 orffinder.orffinder_bin；conda 走 PATH
docker_prefix, tool_bin = docker_wrapper.docker_wrapper_binary(
    snakemake.config,
    "orffinder",
    "orffinder_bin",
    "ORFfinder",
)

input_fasta = str(snakemake.input.fasta)
output_file = str(snakemake.output.file)

# Ensure output directory exists
out_dir = dirname(output_file)
if out_dir and not exists(out_dir):
    shell(f"mkdir -p {out_dir}")

# Decompress gz if needed
if input_fasta.endswith(".gz"):
    input_fa = input_fasta.rsplit(".gz")[0]
    shell(f"gunzip -c {input_fasta} > {input_fa}")
else:
    input_fa = input_fasta

# Run ORFfinder（进度日志 -> snakemake log 文件）
shell(f"{docker_prefix}{tool_bin} -in {input_fa} -out {output_file} -outfmt {outfmt} {extra} -logfile {log_file}")
