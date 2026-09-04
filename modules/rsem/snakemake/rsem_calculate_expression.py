"""Snakemake wrapper for RSEM calculate-expression（通用单规则配套）。

契约（与同目录 rsem_calculate_expression.smk 一致）：
  - input.bam / input.fq_one / input.fq_two：config rsem_input_bam / rsem_input_fq_one /
    rsem_input_fq_two（BAM 模式与 FASTQ 模式二选一；双端由 fq_two 存在或 params.paired_end 决定）
  - output.genes / output.isoforms：<rsem_out_prefix>.genes.results / .isoforms.results
    （output_prefix 由 output.genes 去 .genes.results 后缀推导）
  - params.index / extra / mean / sd / strandedness / paired_end：透传（config rsem_index_prefix /
    rsem.calculate_expression_params / rsem.fragment_length_mean / rsem.fragment_length_sd /
    rsem.strandedness / rsem.paired_end）
  - 环境：exec_mode conda(默认)/docker/native；native 用 rsem.calculate_expression_bin，
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

# Docker/二进制解析：docker 用镜像内默认名；native 用 config 的 rsem.calculate_expression_bin；conda 走 PATH
docker_prefix, tool_bin = docker_wrapper.docker_wrapper_binary(
    snakemake.config,
    "rsem",
    "calculate_expression_bin",
    "rsem-calculate-expression",
)

bam = snakemake.input.get("bam", [])
fq_one = snakemake.input.get("fq_one", [])
fq_two = snakemake.input.get("fq_two", [])

if bam:
    if fq_one or fq_two:
        raise Exception("Only input.bam or input.fq_one expected, got both.")
    input_bam = "--alignments"
    if len(bam) != 1:
        raise Exception("Expected exactly one input.bam path.")
    input_string = bam[0]
    paired_end = snakemake.params.get("paired_end", False)
else:
    input_bam = ""
    if fq_one:
        input_string = ",".join(fq_one)
        if fq_two:
            if len(fq_one) != len(fq_two):
                raise Exception(
                    "Got {} R1 FASTQs, {} R2 FASTQs.".format(len(fq_one), len(fq_two))
                )
            input_string += " " + ",".join(fq_two)
            paired_end = True
        else:
            paired_end = False
    else:
        raise Exception("Expected input.bam or input.fq_one, got neither.")

if paired_end:
    paired_end_string = "--paired-end"
else:
    paired_end_string = ""

# Output prefix handling
genes_results = snakemake.output.genes
if genes_results.endswith(".genes.results"):
    output_prefix = genes_results[: -len(".genes.results")]
else:
    raise Exception(
        "output.genes file name malformed "
        "(rsem will append .genes.results suffix)"
    )

if not snakemake.output.isoforms.endswith(".isoforms.results"):
    raise Exception(
        "output.isoforms file name malformed "
        "(rsem will append .isoforms.results suffix)"
    )

# Params
index = snakemake.params.index
extra = snakemake.params.get("extra", "")
mean = snakemake.params.get("mean", "")
sd = snakemake.params.get("sd", "")
strandedness = snakemake.params.get("strandedness", "forward")

# Build command parts
frag_mean_cmd = f"--fragment-length-mean {mean}" if mean else ""
frag_sd_cmd = f"--fragment-length-sd {sd}" if sd else ""
strand_cmd = f"--strandedness {strandedness}" if strandedness else ""

log = snakemake.log_fmt_shell(stdout=True, stderr=True)

shell(
    "{docker_prefix}{tool_bin} --num-threads {snakemake.threads} {extra} "
    "{paired_end_string} {strand_cmd} {frag_mean_cmd} {frag_sd_cmd} "
    "{input_bam} {input_string} "
    "{index} {output_prefix} "
    "{log}"
)
