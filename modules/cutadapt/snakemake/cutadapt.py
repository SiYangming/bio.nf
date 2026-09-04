"""Snakemake wrapper for trimming reads using cutadapt (SE/PE)."""

__author__ = "Yangming Si"
__copyright__ = "Copyright 2026, Yangming Si"
__email__ = "siyangming1991@163.com"
__license__ = "MIT"

"""Snakemake wrapper for trimming reads using cutadapt (SE/PE)."""

__author__ = "Yangming Si"
__copyright__ = "Copyright 2026, Yangming Si"
__email__ = "siyangming1991@163.com"
__license__ = "MIT"


from snakemake.shell import shell
import os, sys
# 注入 bioskills 共享库目录（modules/），以导入共享 docker_wrapper
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
import docker_wrapper


n = len(snakemake.input)
assert n in [1, 2], "Input must contain 1 (SE) or 2 (PE) elements."

extra = snakemake.params.get("extra", "")
adapters = snakemake.params.get("adapters", "")
log = snakemake.log_fmt_shell(stdout=False, stderr=True)

docker_prefix, tool_bin = docker_wrapper.docker_wrapper_binary(
    snakemake.config,
    "cutadapt",
    "cutadapt_bin",
    "cutadapt",
)

assert (
    extra != "" or adapters != ""
), "No options provided to cutadapt. Please use 'params: adapters=' or 'params: extra='."

if n == 1:
    # Single-end
    shell(
        "{docker_prefix}{tool_bin}"
        " --cores {snakemake.threads}"
        " {adapters}"
        " {extra}"
        " -o {snakemake.output.fastq}"
        " {snakemake.input[0]}"
        " > {snakemake.output.qc} {log}"
    )
else:
    # Paired-end
    shell(
        "{docker_prefix}{tool_bin}"
        " --cores {snakemake.threads}" # Number of threads
        " {adapters}" # Adapter sequences
        " {extra}" # Optional parameters
        " -o {snakemake.output.fastq1}" # Output file for forward reads
        " -p {snakemake.output.fastq2}" # Output file for reverse reads
        " {snakemake.input.fastq1}" # Input files
        " {snakemake.input.fastq2}"
        " > {snakemake.output.qc} {log}" # Log file
    )
