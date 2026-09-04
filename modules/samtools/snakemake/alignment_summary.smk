# alignment_summary.smk —— samtools flagstat 汇总 单规则（Snakemake，td2 式）
#
# 设计：config 驱动、批量汇总规则（多 flagstat 文本 -> 一张汇总 TSV），不依赖 workflow 的
#       SAMPLES / config[paths] / output_dir 目录约定（原聚合 samtools.smk rule alignment_summary
#       依赖流程 expand(SAMPLES) 与 01_MINIMAP2_ALIGN/FLAGSTAT 层级，已改为 config 列表键）。
#       wrapper：同目录 alignment_summary.py（纯标准库解析，无 conda 依赖，故本规则不配 conda）。
#
# 独立运行/流程内使用（flagstats 列表无法用命令行 --config 传 list，在流程内 include 后赋值）：
#   include: "modules/samtools/snakemake/alignment_summary.smk"
#   config["alignment_summary_flagstats"] = ["out/s1.flagstat.txt", "out/s2.flagstat.txt"]
#   rule all:
#       input: config["alignment_summary_out"]
#
# config 契约（均有默认）：
#   alignment_summary_flagstats : 输入 flagstat 文本列表（流程内赋值；默认 []）
#   alignment_summary_out       : 汇总 TSV 输出（默认 alignment_summary.txt）

import os

config.setdefault("alignment_summary_flagstats", [])
config.setdefault("alignment_summary_out", "alignment_summary.txt")

rule alignment_summary:
    """汇总多个 samtools flagstat 文本为 Sample/Total/Mapped/Rate 表格。"""
    input:
        flagstats=config["alignment_summary_flagstats"]
    output:
        summary=config["alignment_summary_out"]
    log:
        os.path.join(os.path.dirname(config["alignment_summary_out"]), "alignment_summary.log")
    script: "alignment_summary.py"
