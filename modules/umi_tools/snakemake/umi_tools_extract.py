"""Snakemake wrapper for umi_tools extract（通用单样本规则配套）。

契约（与同目录 umi_tools_extract_se.smk / umi_tools_extract_pe.smk 一致）：
  - input.fastq1（SE）/ input.fastq1 + input.fastq2（PE）：R1/R2 输入
    （config umi_input_fastq / umi_input_fastq2）
  - output.fastq（SE）/ output.fastq1 + output.fastq2（PE）：UMI 标记输出
    （config umi_output_fastq / umi_output_fastq2）
  - params.extract_method / params.bc_pattern：extract 方法（string|regex）与条形码模式
    （config umi_tools.extract_method / umi_tools.bc_pattern）
  - params.extra：透传附加参数（config umi_tools.extra_params，如 "--bc-pattern2=NNNNNNNN --3prime"）
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

# Extract params
extract_method = snakemake.params.get("extract_method", "")
bc_pattern = snakemake.params.get("bc_pattern", "")

# Determine input/output files (SE or PE)
input_fwd = getattr(snakemake.input, "fastq", None) or getattr(snakemake.input, "fastq1", None) or getattr(snakemake.input, "fq1", None)
input_rev = getattr(snakemake.input, "fastq2", None) or getattr(snakemake.input, "fq2", None)

output_fwd = getattr(snakemake.output, "fastq", None) or getattr(snakemake.output, "fastq1", None) or getattr(snakemake.output, "out1", None)
output_rev = getattr(snakemake.output, "fastq2", None) or getattr(snakemake.output, "out2", None)

if not input_fwd or not output_fwd:
    raise ValueError("Could not determine input/output fastq files from rule.")

# Construct command
# Basic structure: umi_tools extract -I input -S output [options]
cmd_parts = [
    f"{docker_prefix}{tool_bin} extract",
    f"-I {input_fwd}",
    f"-S {output_fwd}",
]

# PE options
if input_rev and output_rev:
    cmd_parts.append(f"--read2-in={input_rev}")
    cmd_parts.append(f"--read2-out={output_rev}")

# Params
if extract_method:
    cmd_parts.append(f"--extract-method={extract_method}")

if bc_pattern:
    cmd_parts.append(f"--bc-pattern='{bc_pattern}'")

if extra:
    cmd_parts.append(extra)

cmd_parts.append(log)

# Execute
shell(" ".join(cmd_parts))
