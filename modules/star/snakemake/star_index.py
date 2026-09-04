"""Snakemake wrapper for STAR index（genomeGenerate，单规则通用样本配套）。

契约（与同目录 star_index.smk 一致）：
  - input.fasta：参考基因组 FASTA（config star_genome_fasta，--genomeFastaFiles）
  - input.gtf（可选）：注释 GTF（config star_gtf，--sjdbGTFfile，生成剪接位点索引）
  - output[0]：STAR 索引目录（config star_index_dir，默认 <outdir>/star_index）
  - params.sjdbOverhang / params.extra：透传（config star.sjdb_overhang / star.index_extra）
  - 环境：exec_mode conda(默认)/docker/native；native 用 star.star_bin，conda/docker 走 PATH 或镜像
"""

from __future__ import annotations

import os
import sys
import tempfile

from snakemake.shell import shell

# 注入 bioskills 共享库目录（modules/），以导入共享 docker_wrapper
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
import docker_wrapper  # noqa: E402

log = snakemake.log_fmt_shell(stdout=True, stderr=True)
extra = snakemake.params.get("extra", "")

# Docker/二进制解析：docker 用镜像内默认名；native 用 config 的 star.star_bin；conda 走 PATH
docker_prefix, tool_bin = docker_wrapper.docker_wrapper_binary(
    snakemake.config,
    "star",
    "star_bin",
    "STAR",
)

sjdb_overhang = snakemake.params.get("sjdbOverhang", "")
if sjdb_overhang:
    sjdb_overhang = f"--sjdbOverhang {sjdb_overhang}"

gtf = snakemake.input.get("gtf", "")
if gtf:
    gtf = f"--sjdbGTFfile {gtf}"

# Ensure output directory exists
outdir = snakemake.output[0]
if not os.path.exists(outdir):
    os.makedirs(outdir)

# Create temp dir inside outdir to ensure it's visible to Docker (if mounted)
with tempfile.TemporaryDirectory(dir=outdir) as tmpdir:
    shell(
        "{docker_prefix}{tool_bin}"
        " --runThreadN {snakemake.threads}"  # Number of threads
        " --runMode genomeGenerate"  # Indexation mode
        " --genomeFastaFiles {snakemake.input.fasta}"  # Path to fasta files
        " {sjdb_overhang}"  # Read-len - 1
        " {gtf}"  # Highly recommended GTF
        " {extra}"  # Optional parameters
        " --outTmpDir {tmpdir}/STARtmp"  # Temp dir
        " --genomeDir {outdir}"  # Path to output
        " {log}"
    )
