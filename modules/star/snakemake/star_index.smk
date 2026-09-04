# star_index.smk —— STAR genomeGenerate 单规则（Snakemake）
#
# 环境：同目录 star.yaml（conda 相对本文件目录解析）；wrapper：同目录 star_index.py。
# 设计：config 驱动、参考 FASTA（+可选 GTF）→ STAR 索引目录，不依赖 workflow 的
#       SAMPLES / {sample} 层级（规则源自 riboseq workflow/rules/star.smk 的 star_index，
#       已去掉对流程级 config[paths]/rnaseq 上下文的依赖）。
#
# 独立运行示例：
#   snakemake -s modules/star/snakemake/star_index.smk \
#       --config star_genome_fasta=refs.fa star_outdir=star_out threads=8 \
#       --cores 8 --use-conda
# 流程内使用（配合 star_align.smk）：
#   include: "modules/star/snakemake/star_index.smk"
#   include: "modules/star/snakemake/star_align.smk"
#   rule all:
#       input: os.path.join(config["star_outdir"], "align", "<reads 前缀>.bam")  # 见 star_align.smk 头注
#
# config 契约（均有默认；独立运行时用 --config 覆盖顶层键，star.* 需在 Snakefile 的
# config/config.yaml 预设，与 td2 式规范一致）：
#   exec_mode                  : conda(默认) | docker | native
#   star.docker_image          : exec_mode=docker 时必填（镜像名）
#   star.star_bin              : exec_mode=native 时的 STAR 路径（默认 STAR，走 PATH）
#   star.sjdb_overhang         : --sjdbOverhang（默认 100，建议 readLength-1）
#   star.index_extra           : 透传 extra，如 "--genomeSAindexNbases 5"（小基因组 <2^14 bp 必调小）
#   star_genome_fasta          : 必填 参考基因组 FASTA（--genomeFastaFiles）
#   star_gtf                   : 可选 注释 GTF（--sjdbGTFfile，生成剪接位点索引）
#   star_outdir                : 输出根（默认 star_out；索引产物在 <outdir>/star_index/）
#   star_index_dir             : 索引目录（默认 <outdir>/star_index；与 star_align.smk 共用同一键）
#   threads                    : 规则调度线程（默认 4；index 建议 8）

import os

config.setdefault("exec_mode", "conda")
config.setdefault("star_genome_fasta", "")
config.setdefault("star_gtf", "")
config.setdefault("star_outdir", "star_out")
config.setdefault("threads", 4)
_star = config.setdefault("star", {})
_star.setdefault("docker_image", "")
_star.setdefault("star_bin", "STAR")
_star.setdefault("sjdb_overhang", 100)
_star.setdefault("index_extra", "")

_star_index_dir = config.setdefault("star_index_dir", os.path.join(config["star_outdir"], "star_index"))


def _star_index_input(wildcards):
    """构建 rule 输入：gtf 为可选，未配置时不占 input 槽位（wrapper 内 .get("gtf") 兜底）。"""
    d = {"fasta": config["star_genome_fasta"]}
    if config["star_gtf"]:
        d["gtf"] = config["star_gtf"]
    return d


rule star_index:
    """STAR --runMode genomeGenerate：参考 FASTA（+可选 GTF）→ STAR 索引目录（<outdir>/star_index/）。"""
    input:
        unpack(_star_index_input)
    output:
        dir=directory(_star_index_dir)
    params:
        sjdbOverhang=_star["sjdb_overhang"],
        extra=_star["index_extra"]
    conda: "star.yaml"
    log:
        os.path.join(config["star_outdir"], "logs", "star_index.log")
    threads:
        config["threads"]
    message:
        "STAR index: {input.fasta} -> {output.dir}"
    script:
        "star_index.py"
