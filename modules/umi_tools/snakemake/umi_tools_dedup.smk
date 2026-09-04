# umi_tools_dedup.smk —— umi_tools dedup 单规则（Snakemake，td2 式）
#
# 环境：同目录 umi_tools.yaml（conda 相对本文件目录解析）；wrapper：同目录 umi_tools_dedup.py。
# 设计：config 驱动、单样本通用，不依赖 workflow 的 samples / config[paths] 层级。
# 说明：输入为已比对 BAM（read 头含 UMI，由 umi_tools_extract_se/pe.smk 产出或外部流程提供）。
#
# 独立运行示例：
#   snakemake -s modules/umi_tools/snakemake/umi_tools_dedup.smk \
#       --config umi_input_bam=aln_sorted.bam \
#       umi_output_bam=aln_dedup.bam 'umi_tools.extra_params=--method directional' \
#       umi_dedup_stats_prefix=dedup_stats --cores 4 --use-conda
# 流程内使用（可分别 include SE/PE/dedup 单规则文件）：
#   include: "modules/umi_tools/snakemake/umi_tools_extract_se.smk"
#   include: "modules/umi_tools/snakemake/umi_tools_extract_pe.smk"
#   include: "modules/umi_tools/snakemake/umi_tools_dedup.smk"
#
# config 契约（均有默认；独立运行时用 --config 覆盖）：
#   exec_mode                  : conda(默认) | docker | native
#   umi_tools.docker_image     : exec_mode=docker 时必填（镜像名）
#   umi_tools.umi_tools_bin    : exec_mode=native 时的 umi_tools 路径（默认 umi_tools，走 PATH）
#   umi_tools.extra_params     : 透传 extra（如 "--method directional --paired"，默认 directional）
#   umi_input_bam              : 必填 输入 BAM（UMI 已写入 read 头）
#   umi_output_bam             : 输出去重 BAM（默认 umi_out/umi_dedup.bam）
#   umi_dedup_stats_prefix     : 可选 --output-stats 前缀（默认空=不生成；如 umi_out/stats/dedup）
#   threads                    : 规则调度线程（默认 4）

import os

config.setdefault("exec_mode", "conda")
config.setdefault("umi_input_bam", "")
config.setdefault("umi_output_bam", os.path.join("umi_out", "umi_dedup.bam"))
config.setdefault("umi_dedup_stats_prefix", "")
config.setdefault("threads", 4)
_ut = config.setdefault("umi_tools", {})
_ut.setdefault("docker_image", "")
_ut.setdefault("umi_tools_bin", "umi_tools")
_ut.setdefault("extra_params", "")

rule umi_tools_dedup:
    """umi_tools dedup：按 UMI + 比对坐标去 PCR 重复（输出去重 BAM，可选 stats）。"""
    input:
        bam=config["umi_input_bam"]
    output:
        bam=config["umi_output_bam"]
    params:
        stats_prefix=config["umi_dedup_stats_prefix"],
        extra=_ut["extra_params"]
    conda: "umi_tools.yaml"
    log:
        os.path.join(os.path.dirname(config["umi_output_bam"]), "umi_tools_dedup.log")
    threads:
        config["threads"]
    message:
        "umi_tools dedup: {input.bam} -> {output.bam}"
    script:
        "umi_tools_dedup.py"
