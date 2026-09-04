"""Snakemake script for fastqc."""

__author__ = "Yangming Si"
__copyright__ = "Copyright 2026, Yangming Si"
__email__ = "siyangming1991@163.com"
__license__ = "MIT"


from os import path
import re
from tempfile import TemporaryDirectory
from snakemake.shell import shell
import os, sys
# 注入 bioskills 共享库目录（modules/），以导入共享 docker_wrapper
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
import docker_wrapper


extra = snakemake.params.get("extra", "")
log = snakemake.log_fmt_shell(stdout=True, stderr=True)
# Define memory per thread (https://github.com/s-andrews/FastQC/blob/master/fastqc#L201-L222)
mem_overhead_factor = snakemake.params.get("mem_overhead_factor", 0.1)
assert (
    0 <= mem_overhead_factor < 1
), f"mem_overhead_factor must be between 0 and 1, got {mem_overhead_factor}"
mem_per_thread_mb = int(
    int(snakemake.resources.get("mem_mb", 8192)) / snakemake.threads * (1.0 - mem_overhead_factor)
)
if mem_per_thread_mb < 100:
    mem_per_thread_mb = 100

docker_prefix, tool_bin = docker_wrapper.docker_wrapper_binary(
    snakemake.config,
    "fastqc",
    "fastqc_bin",
    "fastqc",
)

def basename_without_ext(file_path):
    """Returns basename of file path, without the file extension."""
    base = path.basename(file_path)
    # Remove file extension(s) (similar to the internal fastqc approach)
    base = re.sub("\\.gz$", "", base)
    base = re.sub("\\.bz2$", "", base)
    base = re.sub("\\.txt$", "", base)
    base = re.sub("\\.fastq$", "", base)
    base = re.sub("\\.fq$", "", base)
    base = re.sub("\\.sam$", "", base)
    base = re.sub("\\.bam$", "", base)
    return base

# If you have multiple input files fastqc doesn't know what to do. Taking silently only first gives unapreciated results

if len(snakemake.input) > 1:
    raise IOError("Got multiple input files, I don't know how to process them!")

# Run fastqc, since there can be race conditions if multiple jobs
# use the same fastqc dir, we create a temp dir.
with TemporaryDirectory(dir=path.abspath(".")) as tempdir:
    shell(
        "{docker_prefix}{tool_bin}"
        " --threads {snakemake.threads}"
        " --memory {mem_per_thread_mb}"
        " {extra}"
        " --outdir {tempdir:q}"
        " {snakemake.input[0]:q}"
        " {log}"
    )

    # Move outputs into proper position.
    output_base = basename_without_ext(snakemake.input[0])
    html_path = path.join(tempdir, output_base + "_fastqc.html")
    zip_path = path.join(tempdir, output_base + "_fastqc.zip")

    if snakemake.output.html != html_path:
        shell("mv {html_path:q} {snakemake.output.html:q}")

    if snakemake.output.zip != zip_path:
        shell("mv {zip_path:q} {snakemake.output.zip:q}")
