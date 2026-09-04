# rsem_prepare_reference.smk —— rsem-prepare-reference 建索引 单规则（Snakemake）
#
# 环境：同目录 rsem.yaml（conda 相对本文件目录解析）；wrapper：同目录 rsem_prepare_reference.py。
# 设计：config 驱动、通用流程（td2 式）；不依赖 workflow 的 SAMPLES / riboseq 流程上下文。
#
# 独立运行示例：
#   snakemake -s modules/rsem/snakemake/rsem_prepare_reference.smk \
#       --config rsem_input_fasta=genome.fa rsem_gtf=genes.gtf rsem_index_prefix=rsem_idx \
#       --cores 8 --use-conda
# 流程内使用（与 rsem_calculate_expression.smk 共用同一 rsem_index_prefix 即自动建立依赖）：
#   include: "modules/rsem/snakemake/rsem_prepare_reference.smk"
#   include: "modules/rsem/snakemake/rsem_calculate_expression.smk"
#   rule all:
#       input: config["rsem_out_prefix"] + ".genes.results"  # 见 calculate 规则头注
#
# config 契约（均有默认；独立运行时用 --config 覆盖）：
#   exec_mode                     : conda(默认) | docker | native
#   rsem.docker_image             : exec_mode=docker 时必填（镜像名）
#   rsem.prepare_reference_bin    : exec_mode=native 时的 rsem-prepare-reference 路径（默认走 PATH）
#   rsem.prepare_reference_params : 透传 rsem-prepare-reference 附加参数（如 --bowtie2 / --bowtie2-path）
#   rsem_input_fasta              : 必填 参考基因组 FASTA（可 .gz）
#   rsem_gtf                      : 可选 GTF 注释（提供则 wrapper 自动补 --gtf）
#   rsem_index_prefix             : 索引输出前缀（默认 rsem_out/index/rsem；产物 .seq/.grp/.ti/.transcripts.fa 同前缀）
#   threads                       : 规则调度线程（默认 8）

import os

config.setdefault("exec_mode", "conda")
config.setdefault("rsem_input_fasta", "")
config.setdefault("rsem_gtf", "")
config.setdefault("rsem_index_prefix", os.path.join("rsem_out", "index", "rsem"))
config.setdefault("threads", 8)
_rsem = config.setdefault("rsem", {})
_rsem.setdefault("docker_image", "")
_rsem.setdefault("prepare_reference_bin", "rsem-prepare-reference")
_rsem.setdefault("prepare_reference_params", "")

rule rsem_prepare_reference:
    """rsem-prepare-reference：参考 FASTA (+GTF) → RSEM 参考索引（*.seq/.grp/.ti/.transcripts.fa）。"""
    input:
        reference_genome=config["rsem_input_fasta"]
    output:
        seq=config["rsem_index_prefix"] + ".seq",
        grp=config["rsem_index_prefix"] + ".grp",
        ti=config["rsem_index_prefix"] + ".ti",
        transcripts=config["rsem_index_prefix"] + ".transcripts.fa"
    params:
        gtf=config["rsem_gtf"],
        extra=_rsem["prepare_reference_params"]
    conda: "rsem.yaml"
    log:
        os.path.join(os.path.dirname(config["rsem_index_prefix"]), "rsem_prepare_reference.log")
    threads:
        config["threads"]
    message:
        "rsem-prepare-reference: {input.reference_genome} -> {output.seq}（.grp/.ti/.transcripts.fa 同前缀）"
    script:
        "rsem_prepare_reference.py"
