"""Snakemake wrapper for TD2 Predict（通用单样本规则配套）。

契约（与同目录 td2_predict.smk 一致）：
  - input.fasta：明文转录本 FASTA（config td2_input_fasta，不支持 .gz）
  - input.longorfs_dir：TD2.LongOrfs 产物目录（config td2_outdir/longorfs，directory 依赖）
  - output.dir：TD2.Predict 输出目录（config td2_outdir/predict）
  - params.retain_*_hits / params.extra：可选证据与透传（config td2.*）
  - 产物：<fasta 文件名>.TD2.{pep,gff3,cds,bed} 落于 output.dir
    （兼容 TD2 写当前目录或写 -O 两种行为：先 cd 到 output.dir 执行，再把落在 longorfs 目录的产物搬回）
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

# 可选证据输入
addl_outputs = ""
mmseqs = snakemake.params["retain_mmseqs_hits"]
if mmseqs:
    addl_outputs += f" --retain-mmseqs-hits {mmseqs}"
blast = snakemake.params["retain_blastp_hits"]
if blast:
    addl_outputs += f" --retain-blastp-hits {blast}"
hmmer = snakemake.params["retain_hmmer_hits"]
if hmmer:
    addl_outputs += f" --retain-hmmer-hits {hmmer}"

# Docker/二进制解析
docker_prefix, tool_bin = docker_wrapper.docker_wrapper_binary(
    snakemake.config,
    "td2",
    "predict_bin",
    "TD2.Predict",
)

# Prepare output dir
os.makedirs(output_dir, exist_ok=True)

# TD2.Predict -t <fasta> -O <longorfs_dir> [retain/extra]
# 在 output.dir 内执行，覆盖 TD2 将产物写入当前工作目录的情况
cwd_old = os.getcwd()
os.chdir(output_dir)
try:
    shell(f"{docker_prefix}{tool_bin} -t {input_fasta} -O {longorfs_dir} {addl_outputs}{extra}{log}")
finally:
    os.chdir(cwd_old)

# 若 TD2 把产物写入了 -O（longorfs 目录），再搬回 output.dir
fasta_basename = os.path.basename(input_fasta)
for ext in ["pep", "gff3", "cds", "bed"]:
    src = os.path.join(longorfs_dir, f"{fasta_basename}.TD2.{ext}")
    dest = os.path.join(output_dir, f"{fasta_basename}.TD2.{ext}")
    if os.path.exists(src) and not os.path.exists(dest):
        shell(f"mv {src} {dest}")
