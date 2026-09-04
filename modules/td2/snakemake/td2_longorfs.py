"""Snakemake wrapper for TD2 LongOrfs（通用单样本规则配套）。

契约（与同目录 td2_longorfs.smk 一致）：
  - input.fasta：明文转录本 FASTA（config td2_input_fasta，不支持 .gz）
  - output.dir：TD2.LongOrfs 的 -O 输出目录（config td2_outdir/longorfs）
  - params.gene_trans_map / params.extra：透传（config td2.*）
  - 环境：exec_mode conda(默认)/docker/native；native 用 td2.longorfs_bin，conda/docker 走 PATH 或镜像
"""

from __future__ import annotations

import os
import sys

from snakemake.shell import shell

# 注入 bioskills 共享库目录（modules/），以导入共享 docker_wrapper
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
import docker_wrapper  # noqa: E402

extra = str(snakemake.params["extra"])
log = snakemake.log_fmt_shell(stdout=True, stderr=True)

gtm_cmd = ""
gtm = snakemake.params["gene_trans_map"]
if gtm:
    gtm_cmd = f" --gene_trans_map {gtm}"

# Docker/二进制解析：docker 用镜像内默认名；native 用 config 的 td2.longorfs_bin；conda 走 PATH
docker_prefix, tool_bin = docker_wrapper.docker_wrapper_binary(
    snakemake.config,
    "td2",
    "longorfs_bin",
    "TD2.LongOrfs",
)

output_dir = str(snakemake.output.dir)
shell(f"mkdir -p {output_dir}")

input_fasta = str(snakemake.input.fasta)

# TD2.LongOrfs -t <fasta> -O <outdir> [--gene_trans_map <gtm>] [extra]
shell(f"{docker_prefix}{tool_bin} -t {input_fasta} -O {output_dir} {gtm_cmd}{extra}{log}")
