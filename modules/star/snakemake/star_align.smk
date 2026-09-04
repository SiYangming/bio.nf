# star_align.smk —— STAR alignReads 单规则（Snakemake）
#
# 环境：同目录 star.yaml（conda 相对本文件目录解析）；wrapper：同目录 star_align.py。
# 设计：config 驱动、单样本通用流程；输入 = star_index.smk 的索引目录 + --config 给的
#       reads，不依赖 workflow 的 SAMPLES / is_pe(row) / {sample} 目录层级。
#       PE/SE 由是否提供 star_reads2 决定（规则源自 riboseq workflow/rules/star.smk
#       的 star_align，已去掉对流程级 samples/config[paths] 的依赖）。
#
# 独立运行示例（需先有索引产物，或用 --config star_index_dir 指向现成索引）：
#   snakemake -s modules/star/snakemake/star_align.smk \
#       --config star_index_dir=star_out/star_index \
#               star_reads1=reads_R1.fastq.gz star_reads2=reads_R2.fastq.gz \
#               star_outdir=star_out --cores 4 --use-conda
#   单端：--config star_index_dir=star_out/star_index star_reads=reads.fastq.gz star_outdir=star_out
# 流程内使用（配合 star_index.smk）：
#   include: "modules/star/snakemake/star_index.smk"
#   include: "modules/star/snakemake/star_align.smk"
#   rule all:
#       input: os.path.join(config["star_outdir"], "align", "<reads 前缀>.bam")
#
# config 契约（均有默认；独立运行时用 --config 覆盖顶层键，star.* 需在 Snakefile 的
# config/config.yaml 预设，与 td2 式规范一致）：
#   exec_mode                  : conda(默认) | docker | native
#   star.docker_image          : exec_mode=docker 时必填（镜像名）
#   star.star_bin              : exec_mode=native 时的 STAR 路径（默认 STAR，走 PATH）
#   star.align_extra           : 透传 extra（默认 "--outSAMtype BAM SortedByCoordinate" → BAM 输出；
#                                覆盖时请保留该串，否则 wrapper 按 SAM stdout 处理）
#   star_reads1                : PE mate1（可选；与 star_reads2 成对）
#   star_reads2                : PE mate2（可选；设置 star_reads1 时必填）
#   star_reads                 : SE reads（可选；与 star_reads1 二选一）
#   star_outdir                : 输出根（默认 star_out；比对产物在 <outdir>/align/）
#   star_index_dir             : 索引目录（默认 <outdir>/star_index；与 star_index.smk 共用同一键）
#   threads                    : 规则调度线程（默认 4）
#
# 产物命名：<reads 输入基名（去 .gz/.fastq/.fq 等）>.bam 及同前缀 _SJ.out.tab，
# 日志 Log.out / Log.final.out 在 <outdir>/logs/。对齐 wrapper 的 stdout 重定向约定，
# 比对结果文件扩展名固定 .bam。

import os

config.setdefault("exec_mode", "conda")
config.setdefault("star_outdir", "star_out")
config.setdefault("threads", 4)
config.setdefault("star_reads1", "")
config.setdefault("star_reads2", "")
config.setdefault("star_reads", "")
_star = config.setdefault("star", {})
_star.setdefault("docker_image", "")
_star.setdefault("star_bin", "STAR")
_star.setdefault("align_extra", "--outSAMtype BAM SortedByCoordinate")

_star_index_dir = config.setdefault("star_index_dir", os.path.join(config["star_outdir"], "star_index"))
_star_align_dir = os.path.join(config["star_outdir"], "align")
_star_logs_dir = os.path.join(config["star_outdir"], "logs")


def _star_align_input(wildcards):
    """构建 rule 输入：idx（索引目录）+ reads（PE: fq1/fq2；SE: fq1）。"""
    if not (config["star_reads1"] or config["star_reads"]):
        raise ValueError("star_align.smk: 需提供 star_reads1/star_reads2（PE）或 star_reads（SE）")
    if config["star_reads1"] and not config["star_reads2"]:
        raise ValueError("star_align.smk: 设置 star_reads1 时必须同时设置 star_reads2（PE）")
    d = {"idx": directory(_star_index_dir)}
    if config["star_reads1"]:
        d["fq1"] = config["star_reads1"]
        d["fq2"] = config["star_reads2"]
    else:
        d["fq1"] = config["star_reads"]
    return d


def _align_prefix():
    """比对产物前缀：输入 reads 基名，剥去 .gz/.bz2 与 .fastq/.fq/.fasta/.fa 扩展名。"""
    name = os.path.basename(config["star_reads1"] or config["star_reads"])
    for ext in (".gz", ".bz2"):
        if name.endswith(ext):
            name = name[: -len(ext)]
    for ext in (".fastq", ".fq", ".fasta", ".fa"):
        if name.endswith(ext):
            name = name[: -len(ext)]
    return name or "aligned"


_align_prefix = _align_prefix()

rule star_align:
    """STAR --runMode alignReads：SE(-U)/PE(-1/-2) reads → 基因组比对 BAM（<outdir>/align/）。"""
    input:
        unpack(_star_align_input)
    output:
        aln=os.path.join(_star_align_dir, f"{_align_prefix}.bam"),
        sj=os.path.join(_star_align_dir, f"{_align_prefix}_SJ.out.tab"),
        log_out=os.path.join(_star_logs_dir, f"{_align_prefix}.Log.out"),
        log_final=os.path.join(_star_logs_dir, f"{_align_prefix}.Log.final.out")
    params:
        extra=_star["align_extra"]
    conda: "star.yaml"
    log:
        os.path.join(_star_logs_dir, "star_align.log")
    threads:
        config["threads"]
    message:
        "STAR align: {input.fq1} -> {output.aln}"
    script:
        "star_align.py"
