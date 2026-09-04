# ultra_sort_gtf.smk —— GTF 排序 单规则（Snakemake，td2 式）
#
# 环境：sort 为系统基础工具（GNU coreutils），本规则不内置 conda env——二进制默认走系统 PATH
#       （Debian bookworm apt coreutils=9.1 / conda-forge::coreutils）；
#       需要 --use-conda 时可复用 modules/gnu_sort 或由调用方提供含 coreutils 的环境。
# 执行：shell: 一行（sort -k1,1 -k4,4n <in.gtf> > <out>.sorted.gtf，stdout=排序结果，stderr 进 log）。
# 设计：config 驱动、单任务通用规则（uLTRA index 前置：GTF 须按染色体+起始位点排序）；
#       输入须为明文、已去 '#' 注释行（.gz 请先 gunzip——可用 modules/gunzip 模块）。
#
# 独立运行示例：
#   snakemake -s modules/ultra/snakemake/ultra_sort_gtf.smk \
#       --config ultra_gtf=refs/genes.gtf ultra_gtf_sorted=refs/genes.sorted.gtf --cores 1
# 流程内使用（配合 ultra_index.smk）：
#   include: "modules/ultra/snakemake/ultra_sort_gtf.smk"
#   include: "modules/ultra/snakemake/ultra_index.smk"
#   rule all:
#       input: config["ultra_gtf_sorted"]
#
# config 契约（均有默认；独立运行时用 --config 覆盖）：
#   ultra_gtf           : 必填 输入 GTF（明文，已去注释行）
#   ultra_gtf_sorted    : 输出排序 GTF（默认 <输入>.sorted.gtf）
#   ultra.sort_bin      : sort 路径（默认 sort，走 PATH）
#
# 注：本规则即 gnu_sort.smk（modules/gnu_sort）的 GTF 专用变体；流程中已有 gnu_sort 时可复用后者，
#     并把 args 设为 "-k1,1 -k4,4n"。

import os

config.setdefault("ultra_gtf", "")
_ultra = config.setdefault("ultra", {})
_ultra.setdefault("sort_bin", "sort")

_gs_in = config["ultra_gtf"]
config.setdefault("ultra_gtf_sorted", _gs_in + ".sorted.gtf" if _gs_in else "")

if not _gs_in:
    raise ValueError("ultra_sort_gtf.smk: 需提供 config['ultra_gtf']（输入 GTF）")

rule ultra_sort_gtf:
    """GTF 排序：sort -k1,1 -k4,4n <in.gtf> > <out>.sorted.gtf（uLTRA index 前置）。"""
    input:
        unsorted=config["ultra_gtf"]
    output:
        sorted=config["ultra_gtf_sorted"]
    params:
        sort_bin=_ultra["sort_bin"]
    log:
        os.path.join(os.path.dirname(config["ultra_gtf_sorted"]), "logs", "ultra_sort_gtf.log")
    message:
        "sort GTF: {input.unsorted} -> {output.sorted}"
    shell:
        "{params.sort_bin} -k1,1 -k4,4n {input} > {output} 2> {log}"
