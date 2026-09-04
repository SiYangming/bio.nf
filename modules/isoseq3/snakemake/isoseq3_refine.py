"""Snakemake wrapper for isoseq3 refine（通用单任务规则配套，与同目录 isoseq3_refine.smk 契约一致）。

语义：lima 产物 BAM + 引物 FASTA -> 精炼 reads BAM（去 polyA 尾与人工连接体；产物
.bam/.pbi/.consensusreadset.xml/.filter_summary.report.json/.report.csv 同前缀平铺于
<isoseq3_outdir>/）。单条命令（mkdir 仅建目录），三模式分派在 wrapper 内完成。

契约：
  - input.bam / input.primers：输入 BAM（config isoseq3_input_bam）/ 引物 FASTA
    （config isoseq3_primers）
  - output.bam：精炼 reads BAM（<isoseq3_outdir>/<prefix>.bam；output[1..4] 为同前缀
    .pbi/.consensusreadset.xml/.filter_summary.report.json/.report.csv）
  - params.polya / params.min_polya / params.extra：--require-polya 旗标（config
    isoseq3.require_polya，默认 true）/ --min-polya-length 旗标（config
    isoseq3.min_polya_length，空则不传）/ 透传 extra（config isoseq3.extra_args）
  - 线程：-j 透传 snakemake.threads（规则 threads = config threads，默认 8）
  - 环境：exec_mode conda(默认) / docker / native；docker 用镜像内 isoseq3，
    native 用 config isoseq3.isoseq3_bin，conda 走 PATH（isoseq3.yaml 含 isoseq3）
"""

from __future__ import annotations

__author__ = "Yangming Si"
__copyright__ = "Copyright 2026, Yangming Si"
__email__ = "siyangming1991@163.com"
__license__ = "MIT"

import os
import sys

from snakemake.shell import shell

# 注入 bioskills 共享库目录（modules/），以导入共享 docker_wrapper
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
import docker_wrapper  # noqa: E402

log = snakemake.log_fmt_shell(stdout=True, stderr=True)

# Docker/native/conda 分派（docker 走镜像内默认名；native 走 config isoseq3.isoseq3_bin；conda 走 PATH）
docker_prefix, tool_bin = docker_wrapper.docker_wrapper_binary(
    snakemake.config,
    "isoseq3",
    "isoseq3_bin",
    "isoseq3",
)

# 确保输出 BAM 与 log 目录存在（Docker 挂载后可访问；snakemake 不为 log 建目录）
out_file = str(snakemake.output.bam)
out_dir = os.path.dirname(out_file)
log_dir = os.path.dirname(str(snakemake.log))
for d in (out_dir, log_dir):
    if d and not os.path.exists(d):
        os.makedirs(d)

polya = snakemake.params.get("polya", "")
min_polya = snakemake.params.get("min_polya", "")
extra = snakemake.params.get("extra", "")

shell(
    f"{docker_prefix}{tool_bin} refine"
    f" -j {snakemake.threads}"
    f" {polya} {min_polya}"
    f" {extra}"
    f" {snakemake.input.bam} {snakemake.input.primers} {out_file}"
    f"{log}"
)
