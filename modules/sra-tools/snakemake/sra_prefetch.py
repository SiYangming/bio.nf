"""Snakemake wrapper for sra-tools prefetch（三模式分派，与同目录 sra_prefetch.smk 契约一致）。

契约：
  - params.srr_id / params.options：accession 与下载选项（config sra_srr_id / sra_tools.prefetch_options）
  - output.sra：<sra_outdir>/<srr_id>/<srr_id>.sra（config sra_prefetch_sra）
  - 环境：exec_mode conda(默认) / docker / native（docker 用 config sra_tools.docker_image；
    native 用 config sra_tools.prefetch_bin；conda 走 PATH）
"""

from __future__ import annotations

import os
import sys

from snakemake.shell import shell

# 注入 bioskills 共享库目录（modules/），以导入共享 docker_wrapper
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
import docker_wrapper  # noqa: E402

docker_prefix, tool_bin = docker_wrapper.docker_wrapper_binary(
    snakemake.config, "sra_tools", "prefetch_bin", "prefetch")

log = snakemake.log_fmt_shell(stdout=True, stderr=True)
options = snakemake.params["options"]
srr_id = snakemake.params["srr_id"]
sra_file = snakemake.output.sra
out_root = os.path.dirname(os.path.dirname(sra_file))  # prefetch -O 落在 <outdir>/
os.makedirs(os.path.dirname(sra_file), exist_ok=True)
os.makedirs(os.path.dirname(os.path.abspath(str(snakemake.log))), exist_ok=True)

shell(
    "{docker_prefix}{tool_bin} {options} "
    "-O {out_root} {srr_id} {log}"
)
shell("test -s {sra_file}")
