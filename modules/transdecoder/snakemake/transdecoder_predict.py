"""Snakemake wrapper for TransDecoder.Predict（td2 式通用单样本规则配套）。

契约（与同目录 transdecoder_predict.smk 一致）：
  - input.fasta：明文转录本 FASTA（config transdecoder_input_fasta，不支持 .gz）
  - input.longorfs_dir：LongOrfs 输出目录（内含 <fasta>.transdecoder_dir/）
  - output.dir：Predict 输出目录 = <transdecoder_outdir>/predict
    先在该目录放置 <fasta>.transdecoder_dir（自 longorfs_dir 复制），再 Predict -O 产出
    <fasta>.transdecoder.{pep,gff3,cds,bed}；结束后清理放置的目录。
  - params.retain_pfam_hits / retain_blastp_hits / extra：透传（config transdecoder.*）
"""

from __future__ import annotations

import os
import sys

from snakemake.shell import shell

# 注入 bioskills 共享库目录（modules/），以导入共享 docker_wrapper
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
import docker_wrapper  # noqa: E402

output_dir = str(snakemake.output.dir)
longorfs_dir = str(snakemake.input.longorfs_dir)
input_fasta = str(snakemake.input.fasta)

extra = str(snakemake.params["extra"])
log = snakemake.log_fmt_shell(stdout=True, stderr=True)

addl_outputs = ""
pfam = snakemake.params["retain_pfam_hits"]
if pfam:
    addl_outputs += f" --retain_pfam_hits {pfam}"
blast = snakemake.params["retain_blastp_hits"]
if blast:
    addl_outputs += f" --retain_blastp_hits {blast}"

# Docker/二进制解析
docker_prefix, tool_bin = docker_wrapper.docker_wrapper_binary(
    snakemake.config,
    "transdecoder",
    "predict_bin",
    "TransDecoder.Predict",
)

os.makedirs(output_dir, exist_ok=True)
fasta_basename = os.path.basename(input_fasta)

# Predict 期望 <outdir>/<fasta>.transdecoder_dir 存在（longorfs 产物在 longorfs_dir 下），先放置
src_dir = os.path.join(longorfs_dir, f"{fasta_basename}.transdecoder_dir")
placed_dir = os.path.join(output_dir, f"{fasta_basename}.transdecoder_dir")
if not os.path.exists(placed_dir) and os.path.isdir(src_dir):
    shell(f"cp -r {src_dir} {placed_dir}")

# TransDecoder.Predict -t <fa> -O <outdir> [retain/extra] -> <outdir>/<fa>.transdecoder.{pep,gff3,cds,bed}
shell(f"{docker_prefix}{tool_bin} -t {input_fasta} -O {output_dir} {addl_outputs}{extra}{log}")

# 清理放置的中间目录（longorfs_dir 中保留原件）
if os.path.isdir(placed_dir):
    shell(f"rm -rf {placed_dir}")
