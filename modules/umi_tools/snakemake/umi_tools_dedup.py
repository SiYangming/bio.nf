"""Snakemake wrapper for umi_tools dedup（通用单样本规则配套）。

契约（与同目录 umi_tools_dedup.smk 一致）：
  - input.bam：按 UMI 去重的输入 BAM（config umi_input_bam；index .bai 由 pysam 自动定位）
  - output：去重 BAM（config umi_output_bam）
  - params.stats_prefix：--output-stats 前缀（config umi_dedup_stats_prefix，默认空=不生成）
  - params.extra：透传附加参数（config umi_tools.extra_params，如 "--method directional --paired"）
  - 环境：exec_mode conda(默认)/docker/native；docker 用 config umi_tools.docker_image，
    native 用 config umi_tools.umi_tools_bin（默认 umi_tools，走 PATH）
"""

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


extra = snakemake.params.get("extra", "")
log = snakemake.log_fmt_shell(stdout=True, stderr=True)

# Docker/Singularity setup
docker_prefix, tool_bin = docker_wrapper.docker_wrapper_binary(
    snakemake.config,
    "umi_tools",
    "umi_tools_bin",
    "umi_tools",
)

# Input/Output
if hasattr(snakemake.input, "bam"):
    input_bam = snakemake.input.bam
else:
    input_bam = snakemake.input[0]

output_bam = snakemake.output[0]

# Params
stats_prefix = snakemake.params.get("stats_prefix", None)

# Construct command
# umi_tools dedup -I input.bam -S output.bam [options]
cmd_parts = [
    f"{docker_prefix}{tool_bin} dedup",
    f"-I {input_bam}",
    f"-S {output_bam}",
]

if stats_prefix:
    cmd_parts.append(f"--output-stats={stats_prefix}")

if extra:
    cmd_parts.append(extra)

cmd_parts.append(log)

# Execute
shell(" ".join(cmd_parts))
