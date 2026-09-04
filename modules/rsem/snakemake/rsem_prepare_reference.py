"""Snakemake wrapper for RSEM prepare-reference（通用单规则配套）。

契约（与同目录 rsem_prepare_reference.smk 一致）：
  - input.reference_genome：参考基因组 FASTA（config rsem_input_fasta，可 .gz）
  - output.seq/.grp/.ti/.transcripts：RSEM 参考索引（config rsem_index_prefix；
    reference_name 由 output.seq 去 .seq 后缀推导）
  - params.gtf / params.extra：透传（config rsem_gtf / rsem.prepare_reference_params；
    gtf 非空自动补 --gtf）
  - 环境：exec_mode conda(默认)/docker/native；native 用 rsem.prepare_reference_bin，
    conda/docker 走 PATH 或镜像
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

# Docker/二进制解析：docker 用镜像内默认名；native 用 config 的 rsem.prepare_reference_bin；conda 走 PATH
docker_prefix, tool_bin = docker_wrapper.docker_wrapper_binary(
    snakemake.config,
    "rsem",
    "prepare_reference_bin",
    "rsem-prepare-reference",
)

# reference_name 由 output.seq 去 .seq 后缀推导
output_directory = os.path.dirname(os.path.abspath(snakemake.output.seq))
seq_file = os.path.basename(snakemake.output.seq)
if seq_file.endswith(".seq"):
    reference_name = os.path.join(output_directory, seq_file[:-4])
else:
    raise Exception("output.seq has an invalid file suffix (must be .seq)")

# Consistency check
for output_variable, output_path in snakemake.output.items():
    if not os.path.abspath(output_path).startswith(reference_name):
        raise Exception(
            "the path for {} is inconsistent with that of output.seq".format(
                output_variable
            )
        )

# Params
extra = snakemake.params.get("extra", "")
gtf = snakemake.params.get("gtf", "")
gtf_cmd = f" --gtf {gtf}" if gtf else ""
log = snakemake.log_fmt_shell(stdout=True, stderr=True)

shell(
    "{docker_prefix}{tool_bin} --num-threads {snakemake.threads} {extra}"
    "{gtf_cmd} {snakemake.input.reference_genome} {reference_name} "
    "{log}"
)
