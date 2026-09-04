"""Snakemake wrapper for TransDecoder.LongOrfs（td2 式通用单样本规则配套）。

契约（与同目录 transdecoder_longorfs.smk 一致）：
  - input.fasta：明文转录本 FASTA（config transdecoder_input_fasta，不支持 .gz）
  - output.dir：LongOrfs 的 -O 基础输出目录 = <transdecoder_outdir>/longorfs
    TransDecoder 在其下创建 <fasta>.transdecoder_dir/（longest_orfs.{pep,gff3,cds}）
  - params.gene_trans_map / params.extra：透传（config transdecoder.*）
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

# Docker/二进制解析
docker_prefix, tool_bin = docker_wrapper.docker_wrapper_binary(
    snakemake.config,
    "transdecoder",
    "longorfs_bin",
    "TransDecoder.LongOrfs",
)

output_dir = str(snakemake.output.dir)
input_fasta = str(snakemake.input.fasta)
os.makedirs(output_dir, exist_ok=True)

# TransDecoder 在输出已存在同名 transdecoder_dir 时会失败（无 --force），先清理旧产物
created_dir = os.path.join(output_dir, f"{os.path.basename(input_fasta)}.transdecoder_dir")
if os.path.exists(created_dir):
    shell(f"rm -rf {created_dir}")

# TransDecoder.LongOrfs -t <fa> -O <outdir> [--gene_trans_map] [extra]
shell(f"{docker_prefix}{tool_bin} -t {input_fasta} -O {output_dir} {gtm_cmd} {extra} {log}")
