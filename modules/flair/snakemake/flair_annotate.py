"""Snakemake wrapper for flair annotate（通用单任务规则配套，与同目录 flair_annotate.smk 契约一致）。

语义：BED12 + GTF -> 带基因注释 BED（flair_collapse 的 -q 输入）。identify_gene_isoform
为单条命令、无额外逻辑，Docker/native/conda 三模式分派在 wrapper 内完成。

契约：
  - input.bed12：BED12（config flair_annotate_input_bed12，bam2bed12 产物）
  - input.gtf：参考注释 GTF（config flair_annotate_gtf）
  - output.annotated_bed：带基因注释 BED（config flair_annotate_output）
  - 环境：exec_mode conda(默认) / docker / native；docker 用镜像内
    identify_gene_isoform，native 用 config flair.identify_gene_isoform_bin，
    conda 走 PATH（flair.yaml 含 identify_gene_isoform）
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

# Docker/native/conda 分派（docker 走镜像内默认名；native 走 config
# flair.identify_gene_isoform_bin；conda 走 PATH）
docker_prefix, tool_bin = docker_wrapper.docker_wrapper_binary(
    snakemake.config,
    "flair",
    "identify_gene_isoform_bin",
    "identify_gene_isoform",
)

# 确保输出目录存在（Docker 挂载后可访问）
out_file = str(snakemake.output.annotated_bed)
out_dir = os.path.dirname(out_file)
if out_dir and not os.path.exists(out_dir):
    os.makedirs(out_dir)

shell(
    f"{docker_prefix}{tool_bin}"
    f" {snakemake.input.bed12} {snakemake.input.gtf} {out_file}"
    f"{log}"
)
