"""Snakemake wrapper for STAR align（alignReads，单规则通用样本配套）。

契约（与同目录 star_align.smk 一致）：
  - input.idx：STAR 索引目录（config star_index_dir；需先运行 star_index.smk）
  - input.fq1：SE 的 -U reads，或 PE 的 mate1（config star_reads / star_reads1）
  - input.fq2（可选）：PE mate2（config star_reads2）
  - output.aln：比对结果（默认 extra 含 "--outSAMtype BAM SortedByCoordinate" → BAM）
  - output.sj / output.log_out / output.log_final：SJ.out.tab / Log.out / Log.final.out
  - params.extra：透传（config star.align_extra，默认 "--outSAMtype BAM SortedByCoordinate"）
  - 环境：exec_mode conda(默认)/docker/native；native 用 star.star_bin，conda/docker 走 PATH 或镜像
"""

from __future__ import annotations

import os
import sys
import tempfile

from snakemake.shell import shell

# 注入 bioskills 共享库目录（modules/），以导入共享 docker_wrapper
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
import docker_wrapper  # noqa: E402

# Docker/二进制解析：docker 用镜像内默认名；native 用 config 的 star.star_bin；conda 走 PATH
docker_prefix, tool_bin = docker_wrapper.docker_wrapper_binary(
    snakemake.config,
    "star",
    "star_bin",
    "STAR",
)

# Extract parameters
extra = snakemake.params.get("extra", "")
log = snakemake.log_fmt_shell(stdout=False, stderr=True)

# Extract inputs
fq1 = snakemake.input.get("fq1")
assert fq1 is not None, "input-> fq1 is a required input parameter"
fq1 = [fq1] if isinstance(fq1, str) else fq1

fq2 = snakemake.input.get("fq2")
if fq2:
    fq2 = [fq2] if isinstance(fq2, str) else fq2
    assert len(fq1) == len(fq2), "input-> equal number of files required for fq1 and fq2"

input_str_fq1 = ",".join(fq1)
input_str_fq2 = ",".join(fq2) if fq2 is not None else ""
input_str = " ".join([input_str_fq1, input_str_fq2]).strip()

# Determine read command
if fq1[0].endswith(".gz"):
    readcmd = "--readFilesCommand zcat"
elif fq1[0].endswith(".bz2"):
    readcmd = "--readFilesCommand bunzip2 -c"
else:
    readcmd = ""

# Handle unmapped output flag
out_unmapped = snakemake.output.get("unmapped", "")
if out_unmapped:
    out_unmapped_flag = "--outReadsUnmapped Fastx"
else:
    out_unmapped_flag = ""

# Get index
index = snakemake.input.get("idx")
assert index is not None, "input-> index is a required input parameter"

# Determine output type
if "--outSAMtype BAM SortedByCoordinate" in extra:
    stdout = "BAM_SortedByCoordinate"
elif "BAM Unsorted" in extra:
    stdout = "BAM_Unsorted"
else:
    stdout = "SAM"

# Ensure output directory exists (implicitly done by snakemake, but good for tempdir context)
out_aln = snakemake.output.aln
out_dir = os.path.dirname(out_aln)

# Use tempdir inside the output directory so Docker can access it (volume mount usually covers the project/output dir)
with tempfile.TemporaryDirectory(dir=out_dir) as tmpdir:
    shell(
        "{docker_prefix}{tool_bin} "
        " --runThreadN {snakemake.threads}"
        " --genomeDir {index}"
        " --readFilesIn {input_str}"
        " {readcmd}"
        " {extra}"
        " {out_unmapped_flag}"
        " --outTmpDir {tmpdir}/STARtmp"
        " --outFileNamePrefix {tmpdir}/"
        " --outStd {stdout}"
        " > {snakemake.output.aln}"
        " {log}"
    )

    # Move additional outputs if requested
    if snakemake.output.get("reads_per_gene"):
        shell("cat {tmpdir}/ReadsPerGene.out.tab > {snakemake.output.reads_per_gene:q}")
    if snakemake.output.get("chim_junc"):
        shell("cat {tmpdir}/Chimeric.out.junction > {snakemake.output.chim_junc:q}")
    if snakemake.output.get("sj"):
        shell("cat {tmpdir}/SJ.out.tab > {snakemake.output.sj:q}")
    if snakemake.output.get("log"):
        shell("cat {tmpdir}/Log.out > {snakemake.output.log:q}")
    if snakemake.output.get("log_out"):
        shell("cat {tmpdir}/Log.out > {snakemake.output.log_out:q}")
    if snakemake.output.get("log_progress"):
        shell("cat {tmpdir}/Log.progress.out > {snakemake.output.log_progress:q}")
    if snakemake.output.get("log_final"):
        shell("cat {tmpdir}/Log.final.out > {snakemake.output.log_final:q}")

    # Handle unmapped reads
    unmapped_files = snakemake.output.get("unmapped")
    if unmapped_files:
        # For PE, unmapped_files should be a list/tuple of 2 files
        # For SE, it might be a single file string or list
        if not fq2:
            # Single end
            if isinstance(unmapped_files, str):
                unmapped_files = [unmapped_files]

            # STAR output: Unmapped.out.mate1
            src = f"{tmpdir}/Unmapped.out.mate1"
            dest = unmapped_files[0]
            cmd = "gzip -c" if dest.endswith(".gz") else "cat"
            shell(f"{cmd} {src} > {dest}")
        else:
            # Paired end
            if isinstance(unmapped_files, str):
                # Should verify if user provided list, but if string, likely error or just one file expected?
                # Usually unmapped output for PE should be 2 files.
                # If snakemake output is named list: output.unmapped usually returns list if multiple.
                unmapped_files = [unmapped_files]

            # STAR output: Unmapped.out.mate1 and Unmapped.out.mate2
            src1 = f"{tmpdir}/Unmapped.out.mate1"
            src2 = f"{tmpdir}/Unmapped.out.mate2"

            if len(unmapped_files) >= 1:
                dest1 = unmapped_files[0]
                cmd1 = "gzip -c" if dest1.endswith(".gz") else "cat"
                shell(f"{cmd1} {src1} > {dest1}")

            if len(unmapped_files) >= 2:
                dest2 = unmapped_files[1]
                cmd2 = "gzip -c" if dest2.endswith(".gz") else "cat"
                shell(f"{cmd2} {src2} > {dest2}")
