# flair_bam2bed12.smk —— flair bam2bed12 单规则（Snakemake，td2 式）
#
# 环境：同目录 flair.yaml（conda 相对本文件目录解析）；wrapper：同目录 flair_bam2bed12.py。
# 设计：config 驱动、单任务通用规则（sorted BAM -> BED12），不依赖 workflow 的
#       SAMPLES / {sample} / output_dir 层级。原聚合 flair.smk rule bam2bed12 的
#       shell 内联管道（bedtools bamtobed -bed12 | python3 bed12_add_trailing_commas.py）
#       含 helper 逻辑，按 AGENT「执行指令选择」迁入同目录 wrapper（勿在 shell 内联），
#       helper 经 wrapper 内 Path(__file__).parent 同目录定位。
#
# 独立运行示例：
#   snakemake -s modules/flair/snakemake/flair_bam2bed12.smk \
#       --config flair_bam2bed12_input=aln.sorted.bam flair_bam2bed12_output=out/aln.bed12 \
#       --cores 4 --use-conda
# 流程内使用（bam2bed12 -> annotate 链，三段链见 flair_collapse.smk 头注）：
#   include: "modules/flair/snakemake/flair_bam2bed12.smk"
#   rule all:
#       input: config["flair_bam2bed12_output"]
#
# config 契约（均有默认；独立运行时用 --config 覆盖顶层键，flair.* 需在 Snakefile 的
# config/config.yaml 预设，与 td2 式规范一致）：
#   exec_mode              : conda(默认) | docker | native
#   flair.docker_image     : exec_mode=docker 时必填（镜像名，需含 bedtools，如官方 flair 镜像）
#   flair.bedtools_bin     : exec_mode=native 时的 bedtools 路径（默认 bedtools，走 PATH）
#   flair_bam2bed12_input  : 必填 输入 sorted BAM
#   flair_bam2bed12_output : 输出 BED12（默认 <输入去扩展名>.bed12）

import os

config.setdefault("exec_mode", "conda")
config.setdefault("flair_bam2bed12_input", "")
_flair = config.setdefault("flair", {})
_flair.setdefault("docker_image", "")
_flair.setdefault("bedtools_bin", "bedtools")
_bam = config["flair_bam2bed12_input"]
_stem = os.path.splitext(_bam)[0] if _bam else ""
config.setdefault("flair_bam2bed12_output", _stem + ".bed12" if _stem else "")

rule flair_bam2bed12:
    """sorted BAM -> BED12（bedtools bamtobed -bed12 + 尾逗号修复 helper，与 FLAIR bam2Bed12 输出格式等价）。"""
    input:
        bam=config["flair_bam2bed12_input"]
    output:
        bed12=config["flair_bam2bed12_output"]
    conda: "flair.yaml"
    log:
        os.path.join(os.path.dirname(config["flair_bam2bed12_output"]), "flair_bam2bed12.log")
    message:
        "flair bam2bed12: {input.bam} -> {output.bed12}"
    script:
        "flair_bam2bed12.py"
