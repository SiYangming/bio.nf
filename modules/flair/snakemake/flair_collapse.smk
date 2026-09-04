# flair_collapse.smk —— flair collapse 单规则（Snakemake，td2 式）
#
# 环境：同目录 flair.yaml（conda 相对本文件目录解析）；wrapper：同目录 flair_collapse.py。
# 设计：config 驱动、单任务通用规则（带注释 BED + genome + reads -> 一致性转录本
#       FASTA），不依赖 workflow 的 SAMPLES / {sample} / output_dir 层级。collapse 含
#       多布尔开关拼接、docker/native/conda 分派与产物搬运（isoforms.fa 改名交付），
#       按 AGENT「执行指令选择」用同目录 wrapper（原聚合 flair.smk rule flair_collapse）。
#
# 独立运行示例（direct RNA-seq 参数全默认开启；布尔键需在 config.yaml 里给 false 关闭）：
#   snakemake -s modules/flair/snakemake/flair_collapse.smk \
#       --config flair_collapse_annotated_bed=out/aln.annotated.bed \
#               flair_collapse_genome=hg38.fa flair_collapse_reads=reads.fastq.gz \
#               flair_collapse_gtf=gencode.v49.annotation.gtf \
#               flair_collapse_output=out/aln.flair.collapse.fasta \
#       --cores 8 --use-conda
# 流程内使用（bam2bed12 -> annotate -> collapse 三段链）：
#   include: "modules/flair/snakemake/flair_bam2bed12.smk"
#   include: "modules/flair/snakemake/flair_annotate.smk"
#   include: "modules/flair/snakemake/flair_collapse.smk"
#   rule all:
#       input: config["flair_collapse_output"]
#   链式衔接：令 flair_annotate_input_bed12 == flair_bam2bed12_output、
#            flair_collapse_annotated_bed == flair_annotate_output 即自动建立依赖。
#
# config 契约（均有默认；独立运行时用 --config 覆盖顶层键，flair.* 需在 Snakefile 的
# config/config.yaml 预设，与 td2 式规范一致）：
#   exec_mode                          : conda(默认) | docker | native
#   flair.docker_image                 : exec_mode=docker 时必填（镜像名）
#   flair.flair_bin                    : exec_mode=native 时的 flair 路径（默认 flair，走 PATH）
#   flair.mm2_args                     : minimap2 参数（默认 "-I8g,--MD"）
#   flair.collapse_extra               : 透传 extra（慎用）
#   flair_collapse_annotated_bed       : 必填 带基因注释 BED（annotate 产物）
#   flair_collapse_genome              : 必填 参考基因组 FASTA（-g）
#   flair_collapse_reads               : 必填 原始 reads FASTQ/FASTA（-r，支持 .gz）
#   flair_collapse_gtf                 : 可选 参考注释 GTF（-f）
#   flair_collapse_min_support         : -s 最小 read 支持数（默认 3）
#   flair_collapse_end_window          : -w 3'/5' 端窗口（默认 100）
#   flair_collapse_intpriming_threshold: --intprimingthreshold 内部加尾修剪阈值（默认 30）
#   flair_collapse_trust_ends          : --trust_ends（默认 true）
#   flair_collapse_remove_internal_priming : --remove_internal_priming（默认 true）
#   flair_collapse_stringent           : --stringent（默认 true）
#   flair_collapse_check_splice        : --check_splice（默认 true）
#   flair_collapse_quiet               : --quiet（默认 true）
#   flair_collapse_output              : 交付 FASTA（默认 <annotated_bed 去扩展名>.flair.collapse.fasta）
#   threads                            : 规则调度线程（默认 8，对齐 meta optimization.collapse）
#
# 产物命名：wrapper 以 <output 去 .flair.collapse.fasta 后缀> 为 -o 前缀，flair collapse
# 生成 <前缀>.isoforms.fa 后搬运为交付文件（flair_collapse_output）；同前缀 .isoforms.bed /
# .isoforms.gff3 / .counts.tsv 等旁产物留在输出目录。

import os

config.setdefault("exec_mode", "conda")
config.setdefault("threads", 8)
config.setdefault("flair_collapse_annotated_bed", "")
config.setdefault("flair_collapse_genome", "")
config.setdefault("flair_collapse_reads", "")
config.setdefault("flair_collapse_gtf", "")
config.setdefault("flair_collapse_min_support", 3)
config.setdefault("flair_collapse_end_window", 100)
config.setdefault("flair_collapse_intpriming_threshold", 30)
config.setdefault("flair_collapse_trust_ends", True)
config.setdefault("flair_collapse_remove_internal_priming", True)
config.setdefault("flair_collapse_stringent", True)
config.setdefault("flair_collapse_check_splice", True)
config.setdefault("flair_collapse_quiet", True)
_flair = config.setdefault("flair", {})
_flair.setdefault("docker_image", "")
_flair.setdefault("flair_bin", "flair")
_flair.setdefault("mm2_args", "-I8g,--MD")
_flair.setdefault("collapse_extra", "")

_abed = config["flair_collapse_annotated_bed"]
_stem = os.path.splitext(_abed)[0] if _abed else ""
config.setdefault("flair_collapse_output", _stem + ".flair.collapse.fasta" if _stem else "")


def _collapse_input(wildcards):
    """构建 rule 输入：gtf 为可选，未配置时不占 input 槽位（wrapper 内 input.get("gtf") 兜底）。"""
    d = {
        "annotated_bed": config["flair_collapse_annotated_bed"],
        "genome": config["flair_collapse_genome"],
        "reads": config["flair_collapse_reads"],
    }
    if config["flair_collapse_gtf"]:
        d["gtf"] = config["flair_collapse_gtf"]
    return d


rule flair_collapse:
    """flair collapse：带注释 BED + genome + reads -> 一致性转录本 FASTA（direct RNA-seq 优化参数）。"""
    input:
        unpack(_collapse_input)
    output:
        consensus=config["flair_collapse_output"]
    params:
        min_support=config["flair_collapse_min_support"],
        end_window=config["flair_collapse_end_window"],
        intpriming_threshold=config["flair_collapse_intpriming_threshold"],
        trust_ends=config["flair_collapse_trust_ends"],
        remove_internal_priming=config["flair_collapse_remove_internal_priming"],
        stringent=config["flair_collapse_stringent"],
        check_splice=config["flair_collapse_check_splice"],
        quiet=config["flair_collapse_quiet"],
        mm2_args=_flair["mm2_args"],
        extra=_flair["collapse_extra"]
    conda: "flair.yaml"
    log:
        os.path.join(os.path.dirname(config["flair_collapse_output"]), "flair_collapse.log")
    threads:
        config["threads"]
    message:
        "flair collapse: {input.annotated_bed} (genome {input.genome}, reads {input.reads}) -> {output.consensus}"
    script:
        "flair_collapse.py"
