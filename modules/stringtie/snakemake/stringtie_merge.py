"""Snakemake wrapper for stringtie merge（td2 式跨样本通用规则配套，与同目录 stringtie_merge.smk 契约一致）。

契约：
  - input.gtf_list    ：GTF 列表文件（每行一个 GTF 路径；config stringtie_gtf_list）
  - output.merged_gtf ：非冗余合并 GTF（config stringtie_merged_gtf）
  - params.gtf_arg    ：参考注释 -G 参数（config stringtie_gtf_annotation，空则不传）
  - params.label      ：合并转录本前缀标签 -l（config stringtie_merge_label，默认 MSTRG）
  - params.min_len    ：最小转录本长度 -m（config stringtie_min_transcript_len，默认 200）
  - params.extra      ：透传 stringtie 附加参数（config stringtie_extra_args）
  - snakemake.threads ：线程数 -p（规则 threads: config["threads"]，默认 4）
  - 环境：exec_mode conda(默认) / docker / native；docker 用 stringtie.docker_image 镜像内
    stringtie，native 用 config stringtie.stringtie_bin，conda 走 PATH（同目录 stringtie.yaml）
"""

from __future__ import annotations

import os
import sys

from snakemake.shell import shell

# 注入 bioskills 共享库目录（modules/），以导入共享 docker_wrapper
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
import docker_wrapper  # noqa: E402

log = snakemake.log_fmt_shell(stdout=True, stderr=True)

# Docker/native/conda 分派（docker 走镜像内默认名；native 走 config 的 stringtie_bin；conda 走 PATH）
docker_prefix, tool_bin = docker_wrapper.docker_wrapper_binary(
    snakemake.config,
    "stringtie",
    "stringtie_bin",
    "stringtie",
)

shell(
    f"{docker_prefix}{tool_bin} --merge {snakemake.params.gtf_arg} -o {snakemake.output.merged_gtf} "
    f"-l {snakemake.params.label} -m {snakemake.params.min_len} -p {snakemake.threads} "
    f"{snakemake.input.gtf_list} {snakemake.params.extra} {log}"
)
