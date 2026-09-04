"""Snakemake wrapper for flair collapse（通用单任务规则配套，与同目录 flair_collapse.smk 契约一致）。

语义：带注释 BED（annotate 产物）+ genome + reads -> 一致性转录本 FASTA。
flair collapse 以 <交付 FASTA 去 .flair.collapse.fasta 后缀> 为 -o 前缀，产物
<前缀>.isoforms.fa 再搬运为交付文件（多步/产物搬运逻辑，故用 wrapper）。

契约：
  - input.annotated_bed：带基因注释 BED（config flair_collapse_annotated_bed）
  - input.genome / input.reads：参考基因组 FASTA / 原始 reads（-g / -r）
  - input.gtf（可选）：参考注释 GTF（-f；config flair_collapse_gtf）
  - output.consensus：交付 FASTA（config flair_collapse_output）
  - params.*：direct RNA-seq 优化参数（min_support/end_window/intpriming_threshold/
    trust_ends/remove_internal_priming/stringent/check_splice/quiet/mm2_args/extra）
  - 环境：exec_mode conda(默认) / docker / native；docker 用镜像内 flair，
    native 用 config flair.flair_bin，conda 走 PATH（flair.yaml 含 flair + minimap2）
"""

from __future__ import annotations

import os
import sys

from snakemake.shell import shell

# 注入 bioskills 共享库目录（modules/），以导入共享 docker_wrapper
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
import docker_wrapper  # noqa: E402

log = snakemake.log_fmt_shell(stdout=True, stderr=True)

# Docker/native/conda 分派（flair 为实际被调二进制）
docker_prefix, tool_bin = docker_wrapper.docker_wrapper_binary(
    snakemake.config,
    "flair",
    "flair_bin",
    "flair",
)

out_file = str(snakemake.output.consensus)
out_dir = os.path.dirname(out_file)
if out_dir and not os.path.exists(out_dir):
    os.makedirs(out_dir)

# -o 前缀 = 交付文件去 .flair.collapse.fasta 后缀（与 nanoseq 原规则一致）
suffix = ".flair.collapse.fasta"
prefix = out_file[: -len(suffix)] if out_file.endswith(suffix) else out_file

gtf = snakemake.input.get("gtf", "")
gtf_arg = f" -f {gtf}" if gtf else ""

cmd = (
    f"{docker_prefix}{tool_bin} collapse"
    f" -q {snakemake.input.annotated_bed}"
    f" -g {snakemake.input.genome}"
    f" -r {snakemake.input.reads}"
    f" -o {prefix}"
    f" -t {snakemake.threads}"
    f"{gtf_arg}"
    f" -s {snakemake.params.min_support}"
    f" -w {snakemake.params.end_window}"
    f" --intprimingthreshold {snakemake.params.intpriming_threshold}"
)

# 布尔开关：config 默认 true（与 nanoseq direct RNA-seq 参数一致），false 时关闭
for name in ("trust_ends", "remove_internal_priming", "stringent", "check_splice", "quiet"):
    if snakemake.params.get(name, True):
        cmd += f" --{name}"

cmd += f' --mm2_args "{snakemake.params.mm2_args}"'

extra = snakemake.params.get("extra", "")
if extra:
    cmd += f" {extra}"

shell(cmd + log)

# 搬运：flair collapse 主 FASTA 为 <前缀>.isoforms.fa -> 交付文件
isoforms_fa = prefix + ".isoforms.fa"
if not os.path.exists(isoforms_fa):
    raise RuntimeError(
        f"flair collapse 未生成 {isoforms_fa}（可能无满足 min_support 的 isoform，"
        f"请检查日志 {snakemake.log}）"
    )
shell(f"cp {isoforms_fa} {out_file}")
