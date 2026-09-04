"""Snakemake wrapper for bamtools convert（BAM -> FASTA/FASTQ 等，td2 式单规则配套）。

契约（与同目录 bamtools_convert.smk 一致）：
  - input.bam：输入 BAM（config bamtools_input_bam）
  - output.out / output.versions：转换产物 + versions.yml（nf-core 风格）
  - params.format / params.extra：转换格式（config bamtools.format，默认 fasta）与附加参数
  - 环境：exec_mode conda(默认)/docker/native；conda 走 PATH（bamtools.yaml），
    docker 用 bamtools.docker_image，native 用 bamtools.bamtools_bin
"""

from __future__ import annotations

import os
import sys

from snakemake.shell import shell

# 注入 bioskills 共享库目录（modules/），以导入共享 docker_wrapper
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
import docker_wrapper  # noqa: E402

log = snakemake.log_fmt_shell(stdout=True, stderr=True)

# Docker/二进制解析：docker 用镜像内默认名；native 用 config 的 bamtools.bamtools_bin；conda 走 PATH
docker_prefix, tool_bin = docker_wrapper.docker_wrapper_binary(
    snakemake.config,
    "bamtools",
    "bamtools_bin",
    "bamtools",
)

fmt = str(snakemake.params.get("format", "fasta"))
extra = str(snakemake.params.get("extra", ""))
in_bam = str(snakemake.input.bam)
out = str(snakemake.output.out)
versions = str(snakemake.output.versions)

os.makedirs(os.path.dirname(out) or ".", exist_ok=True)

cmd = f"{docker_prefix}{tool_bin} convert -format {fmt} -in {in_bam} -out {out}"
if extra:
    cmd += " " + extra
shell(cmd + " " + log)

# 写 versions.yml（nf-core 风格）：bamtools --version 首行含 "bamtools <ver>"（与旧 rule 的
# grep + sed 同语义，换到 python 侧解析）
ver = "unknown"
try:
    for line in shell.get_output(f"{docker_prefix}{tool_bin} --version"):
        if "bamtools" in line:
            ver = line.split("bamtools", 1)[-1].strip() or "unknown"
            break
except Exception:  # noqa: BLE001 —— 版本探测失败不阻断转换，仅记录 unknown
    ver = "unknown"

with open(versions, "w") as fh:
    fh.write("bamtools:\n")
    fh.write(f"    bamtools: {ver}\n")
