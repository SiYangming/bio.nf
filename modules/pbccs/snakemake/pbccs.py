"""Snakemake wrapper for pbccs ccs（通用单任务规则配套，与同目录 pbccs.smk 契约一致）。

语义：subreads BAM -> 单块 HiFi/CCS BAM（--chunk {chunk}/{chunk_total}，含报告与过滤阈值）。
单条命令、无额外逻辑（mkdir 仅建目录），三模式分派在 wrapper 内完成。

契约：
  - input.subreads：subreads BAM（config pbccs_subreads；样本名去 .subreads 推导）
  - output.bam：单块 CCS BAM（config pbccs_outdir/<sample>.chunk{n}.bam）；output[1..4]
    为同前缀 .pbi/.report.txt/.report.json/.metrics.json.gz（config pbccs_outdir）
  - wildcards.chunk / params.chunk_total：当前分块号 / 总分块数（--chunk n/total）
  - params.min_rq/min_passes/min_snr/min_length/max_length/top_passes：ccs 过滤阈值
    （config pbccs.*，默认 0.9/3/2.5/10/50000/60）
  - params.extra：透传 ccs 额外参数（config pbccs.ccs_extra_params，默认 ""）
  - 线程：-j 透传 snakemake.threads（规则 threads = config threads，默认 8）
  - 环境：exec_mode conda(默认) / docker / native；docker 用镜像内 ccs，
    native 用 config pbccs.ccs_bin，conda 走 PATH（pbccs.yaml 含 pbccs）
"""

from __future__ import annotations

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

log = snakemake.log_fmt_shell(stdout=True, stderr=True)

# Docker/native/conda 分派（docker 走镜像内默认名；native 走 config pbccs.ccs_bin；conda 走 PATH）
docker_prefix, tool_bin = docker_wrapper.docker_wrapper_binary(
    snakemake.config,
    "pbccs",
    "ccs_bin",
    "ccs",
)

# 确保输出目录存在（Docker 挂载后可访问）
out_file = str(snakemake.output.bam)
out_dir = os.path.dirname(out_file)
if out_dir and not os.path.exists(out_dir):
    os.makedirs(out_dir)

extra = snakemake.params.get("extra", "")

shell(
    f"{docker_prefix}{tool_bin}"
    f" {snakemake.input.subreads} {out_file}"
    f" --report-file {snakemake.output.report}"
    f" --report-json {snakemake.output.report_json}"
    f" --metrics-json {snakemake.output.metrics}"
    f" --chunk {snakemake.wildcards.chunk}/{snakemake.params.chunk_total}"
    f" --min-rq {snakemake.params.min_rq}"
    f" --min-passes {snakemake.params.min_passes}"
    f" --min-snr {snakemake.params.min_snr}"
    f" --min-length {snakemake.params.min_length}"
    f" --max-length {snakemake.params.max_length}"
    f" --top-passes {snakemake.params.top_passes}"
    f" {extra}"
    f" -j {snakemake.threads}"
    f"{log}"
)
