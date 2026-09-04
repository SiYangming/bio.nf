# rsem_calculate_expression.smk —— rsem-calculate-expression 定量 单规则（Snakemake）
#
# 环境：同目录 rsem.yaml（conda 相对本文件目录解析）；wrapper：同目录 rsem_calculate_expression.py。
# 设计：config 驱动、单样本通用流程；输入 = 已比对 BAM（riboseq 主用法）或 FASTQ 直算，
#       不依赖 workflow 的 SAMPLES / {protocol}_{sample}_{suffix} 路径约定。
#
# 独立运行示例（BAM 模式；需先有 RSEM 索引，或用 --config 指向现成前缀）：
#   snakemake -s modules/rsem/snakemake/rsem_calculate_expression.smk \
#       --config rsem_input_bam=sample_dedup.bam rsem_index_prefix=rsem_idx \
#       rsem_out_prefix=quant/sample --cores 8 --use-conda
# 直算模式（reads 模式；双端提供 rsem_input_fq_two 即自动 --paired-end）：
#   snakemake -s modules/rsem/snakemake/rsem_calculate_expression.smk \
#       --config rsem_input_fq_one=s1_R1.fq.gz rsem_input_fq_two=s1_R2.fq.gz \
#       rsem_index_prefix=rsem_idx rsem_out_prefix=quant/s1 --cores 8 --use-conda
# 流程内使用（与 rsem_prepare_reference.smk 共用同一 rsem_index_prefix 即自动建立依赖）：
#   include: "modules/rsem/snakemake/rsem_prepare_reference.smk"
#   include: "modules/rsem/snakemake/rsem_calculate_expression.smk"
#   rule all:
#       input: config["rsem_out_prefix"] + ".genes.results"
#
# config 契约（均有默认；独立运行时用 --config 覆盖）：
#   exec_mode                     : conda(默认) | docker | native
#   rsem.docker_image             : exec_mode=docker 时必填（镜像名）
#   rsem.calculate_expression_bin : exec_mode=native 时的 rsem-calculate-expression 路径（默认走 PATH）
#   rsem.calculate_expression_params : 透传 rsem-calculate-expression 附加参数
#   rsem.fragment_length_mean     : 片段长度均值（默认 300；riboseq 口径）
#   rsem.fragment_length_sd       : 片段长度标准差（默认 100）
#   rsem.strandedness             : forward(默认) | reverse | none
#   rsem.paired_end               : BAM 模式显式声明双端（默认 false；FASTQ 双端由 fq_two 自动推断）
#   rsem_input_bam                : 可选 已比对 BAM/CRAM（--alignments；与 rsem_input_fq_one 二选一）
#   rsem_input_fq_one             : 可选 单端 reads 或双端 mate1（FASTQ，可 .gz）
#   rsem_input_fq_two             : 可选 双端 mate2（提供即自动 --paired-end）
#   rsem_index_prefix             : RSEM 参考前缀（默认 rsem_out/index/rsem；与 prepare_reference 规则共用）
#   rsem_out_prefix               : 输出前缀（默认 rsem_out/quant/sample；产物 <prefix>.genes/.isoforms.results）
#   threads                       : 规则调度线程（默认 8）

import os

config.setdefault("exec_mode", "conda")
config.setdefault("rsem_input_bam", "")
config.setdefault("rsem_input_fq_one", "")
config.setdefault("rsem_input_fq_two", "")
config.setdefault("rsem_index_prefix", os.path.join("rsem_out", "index", "rsem"))
config.setdefault("rsem_out_prefix", os.path.join("rsem_out", "quant", "sample"))
config.setdefault("threads", 8)
_rsem = config.setdefault("rsem", {})
_rsem.setdefault("docker_image", "")
_rsem.setdefault("calculate_expression_bin", "rsem-calculate-expression")
_rsem.setdefault("calculate_expression_params", "")
_rsem.setdefault("fragment_length_mean", 300)
_rsem.setdefault("fragment_length_sd", 100)
_rsem.setdefault("strandedness", "forward")
_rsem.setdefault("paired_end", False)

_rsem_bam = [] if not config["rsem_input_bam"] else [config["rsem_input_bam"]]
_rsem_fq_one = [] if not config["rsem_input_fq_one"] else [config["rsem_input_fq_one"]]
_rsem_fq_two = [] if not config["rsem_input_fq_two"] else [config["rsem_input_fq_two"]]
_rsem_source = (
    config["rsem_input_bam"]
    or config["rsem_input_fq_one"]
    or config["rsem_input_fq_two"]
    or "(missing: rsem_input_bam / rsem_input_fq_one)"
)

rule rsem_calculate_expression:
    """rsem-calculate-expression：已比对 BAM（--alignments）或 FASTQ 直算 → 基因/转录本定量。"""
    input:
        bam=_rsem_bam,
        fq_one=_rsem_fq_one,
        fq_two=_rsem_fq_two,
        idx=multiext(
            config["rsem_index_prefix"],
            ".seq", ".grp", ".ti",
        )
    output:
        genes=config["rsem_out_prefix"] + ".genes.results",
        isoforms=config["rsem_out_prefix"] + ".isoforms.results"
    params:
        index=config["rsem_index_prefix"],
        extra=_rsem["calculate_expression_params"],
        mean=_rsem["fragment_length_mean"],
        sd=_rsem["fragment_length_sd"],
        strandedness=_rsem["strandedness"],
        paired_end=_rsem["paired_end"]
    conda: "rsem.yaml"
    log:
        os.path.join(os.path.dirname(config["rsem_out_prefix"]), "rsem_calculate_expression.log")
    threads:
        config["threads"]
    message:
        f"rsem-calculate-expression: {_rsem_source} -> {config['rsem_out_prefix']}.genes/.isoforms.results"
    script:
        "rsem_calculate_expression.py"
