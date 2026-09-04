"""Snakemake wrapper for minimap2 align（通用单样本规则配套）。

契约（与同目录 minimap2_align.smk 一致）：
  - input.reads：输入 reads（config minimap2_reads，FASTA/FASTQ，支持 .gz）
  - input.reference（可选）：参考 FASTA（config minimap2_reference；缺省退化为 reads vs reads）
  - output.bam / output.bai / output.versions：排序 BAM + 索引 + versions.yml
  - params.extra / params.cigar_bam：透传（config minimap2.args / minimap2.cigar_bam）
  - 环境：exec_mode conda(默认)/docker/native；native 用 config 的 minimap2.minimap2_bin /
    minimap2.samtools_bin，conda/docker 走 PATH 或镜像

BAM 管线（与 native minimap2_align.py / nf-core minimap2/align 行为一致）：
  minimap2 [args] [-L] -t N -a <ref|reads> <reads>
      | samtools sort -@ N
      | samtools view -@ N -b -h -o <out>.bam
  samtools index <out>.bam                       → <out>.bam.bai
  写 <prefix>.versions.yml（minimap2 + samtools 版本）
"""

from __future__ import annotations

import os
import sys

from snakemake.shell import shell

# 注入 bioskills 共享库目录（modules/），以导入共享 docker_wrapper
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
import docker_wrapper  # noqa: E402

extra = str(snakemake.params.get("extra", "")).strip()
cigar_bam = "-L" if snakemake.params.get("cigar_bam") else ""
threads = snakemake.threads
log = snakemake.log_fmt_shell(stdout=False, stderr=True)

# Docker/二进制解析：docker 用镜像内默认名；native 用 config 的 minimap2.minimap2_bin /
# minimap2.samtools_bin；conda 走 PATH（minimap2 与 samtools 各自解析，管道两端可分别加 docker 前缀）
mm2_prefix, mm2_bin = docker_wrapper.docker_wrapper_binary(
    snakemake.config,
    "minimap2",
    "minimap2_bin",
    "minimap2",
)
sam_prefix, sam_bin = docker_wrapper.docker_wrapper_binary(
    snakemake.config,
    "minimap2",
    "samtools_bin",
    "samtools",
)

reads = str(snakemake.input.reads)
reference = snakemake.input.get("reference")
ref_arg = str(reference) if reference else reads  # 无参考时退化为 reads vs reads

bam = str(snakemake.output.bam)
outdir = os.path.dirname(bam)
shell(f"mkdir -p {outdir}")
log_path = str(snakemake.log)
if log_path:
    shell(f"mkdir -p {os.path.dirname(log_path)}")

# BAM 管线：minimap2 -a | samtools sort | samtools view -b -h -o（管道两端支持独立 docker 前缀）
shell(
    f"{mm2_prefix}{mm2_bin} {extra} -t {threads} {cigar_bam} -a {ref_arg} {reads} | "
    f"{sam_prefix}{sam_bin} sort -@ {threads} | "
    f"{sam_prefix}{sam_bin} view -@ {threads} -b -h -o {bam}{log}"
)
shell(f"{sam_prefix}{sam_bin} index {bam}{log}")

# Versions（<prefix>.versions.yml，与旧 minimap2_align.smk 输出对齐）
mm2_ver = shell(f"{mm2_prefix}{mm2_bin} --version 2>/dev/null | head -n1", capture=True).strip()
sam_ver = shell(f"{sam_prefix}{sam_bin} --version 2>/dev/null | head -n1", capture=True).strip()
with open(snakemake.output.versions, "w") as vf:
    vf.write("minimap2_align:\n")
    vf.write(f"    minimap2: {mm2_ver}\n")
    vf.write(f"    samtools: {sam_ver}\n")
