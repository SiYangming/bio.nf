# umi_tools_extract_dedup.smk —— UMI 阶段聚合接线（Snakemake）
#
# 供 Snakemake 主 Snakefile include 使用：
#   include: "subworkflow/umi_tools_extract_dedup/snakemake/umi_tools_extract_dedup.smk"
# （本文件相对 include 模块层 umi_tools 的三个单规则 smk，路径相对本文件自身解析）
#
# 组合语义：umi_tools extract（SE 或 PE）-> [调用流程自行比对] -> umi_tools dedup。
# 本文件只做「聚合 include」，不内置比对；调用流程把比对后 BAM 接到 dedup 规则的
# config 键（umi_input_bam）即可。
#
# ⚠️ 若主 Snakefile 已按 modules/umi_tools/snakemake/*.smk glob include，
#    请二选一（本文件与 glob 都会定义同名规则，重复 include 会冲突）。
#
# config 契约（各模块 smk 头注有完整说明，顶层键 --config 可覆盖）：
#   extract SE : umi_input_fastq / umi_output_fastq / umi_tools.{bc_pattern, extract_method,...}
#   extract PE : umi_input_fastq + umi_input_fastq2 / umi_output_fastq1/2（umi_tools_extract_pe.smk）
#   dedup      : umi_input_bam / umi_output_bam / umi_dedup_stats_prefix / umi_tools.extra_params
#
# 用法示例（主 Snakefile 内）：
#   config["umi_input_fastq"] = "umi/s1_R1.umi.fastq.gz"     # extract 产物（流程内由比对消耗）
#   config["umi_input_bam"]   = "align/s1.pc.sorted.bam"      # 比对器产物（如 bbmap pc 链）
#   config["umi_output_bam"]  = "umi/s1.dedup.bam"
#   rule all:
#       input: config["umi_output_bam"]

include: "../../../modules/umi_tools/snakemake/umi_tools_extract_se.smk"
include: "../../../modules/umi_tools/snakemake/umi_tools_extract_pe.smk"
include: "../../../modules/umi_tools/snakemake/umi_tools_dedup.smk"
