"""Snakemake wrapper for fastp（SE/PE 清洗，td2 式单规则配套）。

契约（与同目录 fastp_pe.smk / fastp_se.smk 一致）：
  - input.fq1（+ PE 时 input.fq2）：输入 R1 / R2；output 含 out2 即 PE（out2 键存在与否决定）
  - output.out1（/out2，PE 才有）/ output.html / output.json
  - params.adapter_sequence / detect_adapter_for_pe / qualified_quality_phred /
    unqualified_percent_limit / length_required / extra：可选参数透传（config fastp.*）
  - 环境：exec_mode conda(默认)/docker/native；conda 走 PATH（fastp.yaml），
    docker 用 fastp.docker_image，native 用 fastp.fastp_bin
  - 线程：fastp 0.20+ 用 -w/--thread（-t 已被 --trim_tail1 占用），由 snakemake.threads 注入
"""

from __future__ import annotations

import os
import sys

from snakemake.shell import shell

# 注入 bioskills 共享库目录（modules/），以导入共享 docker_wrapper
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
import docker_wrapper  # noqa: E402

log = snakemake.log_fmt_shell(stdout=True, stderr=True)

# Docker/二进制解析：docker 用镜像内默认名；native 用 config 的 fastp.fastp_bin；conda 走 PATH
docker_prefix, tool_bin = docker_wrapper.docker_wrapper_binary(
    snakemake.config,
    "fastp",
    "fastp_bin",
    "fastp",
)

paired = "out2" in snakemake.output.keys()
if paired and "fq2" not in snakemake.input.keys():
    raise ValueError("fastp wrapper: PE 模式但未提供 input.fq2")

cmd = [
    f"{docker_prefix}{tool_bin}",
    "-i", str(snakemake.input.fq1),
]
if paired:
    cmd += ["-I", str(snakemake.input.fq2)]
cmd += ["-o", str(snakemake.output.out1)]
if paired:
    cmd += ["-O", str(snakemake.output.out2)]
cmd += [
    "-h", str(snakemake.output.html),
    "-j", str(snakemake.output.json),
    "-w", str(snakemake.threads),
]

p = snakemake.params
if p.get("adapter_sequence"):
    cmd += ["--adapter_sequence", str(p.adapter_sequence)]
if p.get("detect_adapter_for_pe"):
    cmd.append("--detect_adapter_for_pe")
if p.get("qualified_quality_phred") is not None:
    cmd += ["-q", str(p.qualified_quality_phred)]
if p.get("unqualified_percent_limit") is not None:
    cmd += ["-u", str(p.unqualified_percent_limit)]
if p.get("length_required") is not None:
    cmd += ["-l", str(p.length_required)]
extra = str(p.get("extra", ""))
if extra:
    cmd += extra.split()

shell(" ".join(cmd) + " " + log)
