# bbmap_align.smk —— BBMap 比对 单规则（Snakemake，td2 式）
#
# 环境：同目录 bbmap.yaml；wrapper：同目录 bbtools.py（command=bbmap.sh）。
# 通用比对规则：reads（SE/PE）对参考（ref= 或 path= 索引）比对，输出 SAM。
# Ribo-seq 的 rRNA->tRNA->PC 分层链：以多组 config 多次 include 串联，
# 或用本规则配不同 bbmap_ref/bbmap_index_dir 在流程层展开。
#
# 独立运行：snakemake -s modules/bbmap/snakemake/bbmap_align.smk \
#       --config bbmap_read1=s_R1.fastq.gz bbmap_ref=ref.fa bbmap_sam=out.sam --cores 8 --use-conda
#
# config 契约（均有默认；独立运行时用 --config 覆盖）：
#   exec_mode               : conda(默认) | docker | native
#   bbmap.docker_image      : exec_mode=docker 时必填
#   bbmap.bbmap_bin         : exec_mode=native 时 bbmap.sh 路径（默认走 PATH）
#   bbmap.bbmap_extra       : 透传 bbmap.sh 附加参数
#   bbmap_read1             : 必填 R1（SE 时仅此）
#   bbmap_read2             : 可选 R2（双端）
#   bbmap_ref               : 参考 FASTA（ref=；与索引二选一）
#   bbmap_index_dir         : 既有索引目录（path=；与参考二选一）
#   bbmap_sam               : 输出 SAM 路径（默认 bbmap_out/align.sam）
#   threads                 : 规则调度线程（默认 8）

import os

config.setdefault("exec_mode", "conda")
config.setdefault("bbmap_read1", "")
config.setdefault("bbmap_read2", "")
config.setdefault("bbmap_ref", "")
config.setdefault("bbmap_index_dir", "")
config.setdefault("bbmap_sam", os.path.join("bbmap_out", "align.sam"))
config.setdefault("threads", 8)
_bm = config.setdefault("bbmap", {})
_bm.setdefault("docker_image", "")
_bm.setdefault("bbmap_bin", "bbmap.sh")
_bm.setdefault("bbmap_extra", "")

_bm_reads = [config["bbmap_read1"]] + ([config["bbmap_read2"]] if config["bbmap_read2"] else [])

rule bbmap_align:
    """bbmap.sh：reads 比对到参考/索引，输出 SAM。"""
    input:
        fastq=_bm_reads
    output:
        sam=config["bbmap_sam"]
    params:
        command="bbmap.sh",
        extra=_bm["bbmap_extra"],
        ref=config["bbmap_ref"],
        path=config["bbmap_index_dir"]
    conda: "bbmap.yaml"
    log:
        os.path.join(os.path.dirname(config["bbmap_sam"]), "bbmap_align.log")
    threads:
        config["threads"]
    message:
        "bbmap: {input.fastq} -> {output.sam}"
    script:
        "bbtools.py"
