# bowtie2_align.smk —— bowtie2 比对 单规则（Snakemake）
#
# 环境：同目录 bowtie2.yaml（conda 相对本文件目录解析）；wrapper：同目录 bowtie2_align.py。
# 设计：config 驱动、通用流程（td2 式）；不依赖 workflow 的 SAMPLES / is_pe 辅助。
#
# 独立运行示例（先建索引或复用现有前缀）：
#   snakemake -s modules/bowtie2/snakemake/bowtie2_align.smk \
#       --config bowtie2_read1=s1_R1.fastq.gz bowtie2_read2=s1_R2.fastq.gz \
#       bowtie2_index_prefix=bt2_index/bowtie2 bowtie2_sam=out.sam \
#       --cores 8 --use-conda
# 流程内使用：
#   include: "modules/bowtie2/snakemake/bowtie2_index.smk"
#   include: "modules/bowtie2/snakemake/bowtie2_align.smk"
#   rule all:
#       input: config["bowtie2_sam"]
#
# config 契约（均有默认；独立运行时用 --config 覆盖）：
#   exec_mode                  : conda(默认) | docker | native
#   bowtie2.docker_image       : exec_mode=docker 时必填（镜像名）
#   bowtie2.align_bin          : exec_mode=native 时 bowtie2 路径（默认走 PATH）
#   bowtie2.bowtie2_extra_params : 透传 bowtie2 附加参数（如 -q / --very-sensitive 由 wrapper 自动补）
#   bowtie2_read1              : 必填 R1（SE 时仅此）；支持 fastq/fasta/bam 及 .gz/.bz2
#   bowtie2_read2              : 可选 R2（双端）
#   bowtie2_index_prefix       : 索引前缀（默认 bowtie2_out/index/bowtie2；与 index 规则共用）
#   bowtie2_sam                : 输出 SAM 路径（默认 bowtie2_out/align.sam）
#   threads                    : 规则调度线程（默认 8）

import os

config.setdefault("exec_mode", "conda")
config.setdefault("bowtie2_read1", "")
config.setdefault("bowtie2_read2", "")
config.setdefault("bowtie2_index_prefix", os.path.join("bowtie2_out", "index", "bowtie2"))
config.setdefault("bowtie2_sam", os.path.join("bowtie2_out", "align.sam"))
config.setdefault("threads", 8)
_b2 = config.setdefault("bowtie2", {})
_b2.setdefault("docker_image", "")
_b2.setdefault("align_bin", "bowtie2")
_b2.setdefault("bowtie2_extra_params", "")

_b2_reads = [config["bowtie2_read1"]] + ([config["bowtie2_read2"]] if config["bowtie2_read2"] else [])

rule bowtie2_align:
    """bowtie2：reads（SE/PE）比对到索引，输出 SAM。"""
    input:
        sample=_b2_reads,
        idx=multiext(
            config["bowtie2_index_prefix"],
            ".1.bt2", ".2.bt2", ".3.bt2", ".4.bt2", ".rev.1.bt2", ".rev.2.bt2",
        )
    output:
        sam=config["bowtie2_sam"]
    params:
        extra=_b2["bowtie2_extra_params"]
    conda: "bowtie2.yaml"
    log:
        os.path.join(os.path.dirname(config["bowtie2_sam"]), "bowtie2_align.log")
    threads:
        config["threads"]
    message:
        "bowtie2: {input.sample} -> {output.sam}"
    script:
        "bowtie2_align.py"
