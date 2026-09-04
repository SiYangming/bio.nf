"""Snakemake wrapper for ORFanage（td2 式 config 驱动规则配套）。

契约（与同目录 orfanage.smk 一致）：
  - input.query_dir：预测 GFF3 所在目录（config orfanage_input_query_dir，directory 依赖）；
    wrapper 自动选取 *.transdecoder.gff3（回退 *.gff3）
  - output.gtf：ORFanage 输出 GTF（config orfanage_outdir/orfanage.gtf）
  - params.reference / params.templates：可选参考 FASTA 与必填模板 FASTA（config orfanage.*）
  - params.cleanq/cleant/... / params.lpi/ilpi/... / params.extra：布尔与数值开关透传
  - 环境：exec_mode conda(默认)/docker/native；native 用 orfanage.orfanage_bin，conda/docker 走 PATH 或镜像
"""

from __future__ import annotations

import glob
import os
import sys

from snakemake.shell import shell

# 注入 bioskills 共享库目录（modules/），以导入共享 docker_wrapper
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
import docker_wrapper  # noqa: E402

# Inputs：在 query_dir 内选取 *.transdecoder.gff3（回退 *.gff3）
query_dir = str(snakemake.input.query_dir)
gff_files = glob.glob(os.path.join(query_dir, "*.transdecoder.gff3"))
if not gff_files:
    gff_files = glob.glob(os.path.join(query_dir, "*.gff3"))
if not gff_files:
    raise ValueError(f"No GFF3 file found in {query_dir}")
query = gff_files[0]

# Output
output_file = str(snakemake.output.gtf)
os.makedirs(os.path.dirname(output_file), exist_ok=True)

# Params
p = snakemake.params
reference = p["reference"]
templates = p["templates"]
if isinstance(templates, str):
    templates = [templates]

# 布尔开关
args = []
for flag, key in [
    ("--cleanq", "cleanq"),
    ("--cleant", "cleant"),
    ("--rescue", "rescue"),
    ("--use-id", "use_id"),
    ("--non-aug", "non_aug"),
    ("--keep-all-cds", "keep_all_cds"),
    ("--keep-cds-if-not-found", "keep_cds_if_not_found"),
    ("--spliced-overhang", "spliced_overhang"),
]:
    if p[key]:
        args.append(flag)

# 数值/字符串参数（int() 化，兼容 YAML/--config 的字符串数字）
for flag, key in [("--lpi", "lpi"), ("--ilpi", "ilpi"), ("--mlpi", "mlpi")]:
    if int(p[key]) != -1:
        args.append(f"{flag} {int(p[key])}")
for flag, key in [("--minlen", "minlen"), ("--overhang", "overhang")]:
    if int(p[key]) > 0:
        args.append(f"{flag} {int(p[key])}")
for flag, key in [("--mode", "mode"), ("--stats", "stats")]:
    if p[key]:
        args.append(f"{flag} {p[key]}")

args.append(f"--threads {snakemake.threads}")

# Extra 透传
if p["extra"]:
    args.append(str(p["extra"]))

# Docker/二进制解析：docker 用镜像内默认名；native 用 config 的 orfanage.orfanage_bin；conda 走 PATH
docker_prefix, tool_bin = docker_wrapper.docker_wrapper_binary(
    snakemake.config,
    "orfanage",
    "orfanage_bin",
    "orfanage",
)

# Reference（可选）
ref_args = f"--reference {reference}" if reference else ""

cmd = (f"{docker_prefix}{tool_bin} --query {query} --output {output_file} "
       f"{ref_args} {' '.join(args)} {' '.join(templates)}")

log = snakemake.log_fmt_shell(stdout=True, stderr=True)
shell(f"{cmd} {log}")
