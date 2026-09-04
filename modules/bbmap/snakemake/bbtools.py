"""Snakemake wrapper for bbtools (specifically bbmap)."""

import os
from snakemake.shell import shell
import os, sys
# 注入 bioskills 共享库目录（modules/），以导入共享 docker_wrapper
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
import docker_wrapper

# Extract parameters
command = snakemake.params.get("command", "bbmap.sh")
extra = snakemake.params.get("extra", "")
threads = snakemake.threads
log = snakemake.log_fmt_shell(stdout=False, stderr=True)

# Docker wrapper integration
# Use the command name to derive the config key, e.g. bbmap.sh -> bbmap_bin
# This allows using other bbtools if they are defined in config or falling back to command name
tool_key = command.replace(".sh", "") + "_bin"

docker_prefix, tool_bin = docker_wrapper.docker_wrapper_binary(
    snakemake.config,
    "bbmap",
    tool_key,
    command,
)

# Helper function for boolean flags
def get_bool_flag(name):
    val = snakemake.params.get(name)
    if val is True:
        return f"{name}=t"
    elif val is False:
        return f"{name}=f"
    return ""

# Common boolean flags for bbmap
bool_flags_list = ["nodisk", "unpigz", "machineout", "overwrite", "append"]
bool_flags = []
for flag in bool_flags_list:
    f = get_bool_flag(flag)
    if f:
        bool_flags.append(f)
bool_flags_str = " ".join(bool_flags)

# Input files (reads)
# Can be 'input' or 'fastq' or 'fq'
fq = snakemake.input.get("input") or snakemake.input.get("fastq") or snakemake.input.get("fq")
input_str = ""
if fq:
    if isinstance(fq, (list, tuple)):
        # If multiple files, join with comma for single input arg (e.g. in=f1,f2)
        # OR handle in1=... in2=... for PE if they are distinct lists?
        # For simplicity and bbmap standard usage:
        # - in=file1,file2 (interleaved or separate PE files passed as list)
        # - in1=file1 in2=file2 (explicit PE)
        # The user's example uses expand() which returns a list.
        # If we have explicit fq1/fq2 inputs (like in star script), handle that.
        # But here we just have 'fastq' or 'input'.
        input_str = f"in={','.join(fq)}"
    else:
        input_str = f"in={fq}"

# Reference fasta
ref = snakemake.input.get("ref") or snakemake.params.get("ref")
ref_str = f"ref={ref}" if ref else ""

# Index path (directory)
# If 'path' is in output, we are building the index
out_path = snakemake.output.get("path")
path_str = ""
if out_path:
    # Ensure directory exists (bbmap might create it, but good practice)
    # But directory() output in snakemake handles creation?
    path_str = f"path={out_path}"
else:
    # If 'path' is in input or params, we are using the index
    idx_path = snakemake.input.get("path") or snakemake.params.get("path")
    if idx_path:
        path_str = f"path={idx_path}"

# Output files
out = snakemake.output.get("out") or snakemake.output.get("bam") or snakemake.output.get("sam")
out_str = f"out={out}" if out else ""

outm = snakemake.output.get("mapped") or snakemake.output.get("outm")
outm_str = f"outm={outm}" if outm else ""

outu = snakemake.output.get("unmapped") or snakemake.output.get("outu")
outu_str = f"outu={outu}" if outu else ""

# Construct and run command
shell(
    "{docker_prefix}{tool_bin} "
    "threads={threads} "
    "{input_str} "
    "{ref_str} "
    "{path_str} "
    "{out_str} "
    "{outm_str} "
    "{outu_str} "
    "{extra} "
    "{bool_flags_str} "
    "{log}"
)
