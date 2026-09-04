# samtools_sam_to_bam.smk —— samtools sam->bam 单规则（Snakemake，td2 式）
#
# 环境：同目录 samtools.yaml（conda 相对本文件目录解析）；wrapper：同目录 samtools_sam_to_bam.py。
# 设计：config 驱动、单任务通用规则（SAM -> BAM），不依赖 workflow 的 samples / config[paths]；
#       对应 riboseq 流程中的中间格式转换步骤（固定 `samtools view -b`，无过滤）。输出为流程
#       中间产物，规则内以 temp() 标记（被下游消费后自动清理；作为最终目标独立运行时不会被
#       删除）。单条命令按 AGENT「执行指令选择」经 script wrapper（samtools_sam_to_bam.py）
#       做 docker/native/conda 三模式分派（exec_mode），命令串与原 shell 语义一致
#       （固定 view -b + -@ threads-1）。
#
# 独立运行示例：
#   snakemake -s modules/samtools/snakemake/samtools_sam_to_bam.smk \
#       --config samtools_sam_to_bam_input=aln.sam samtools_sam_to_bam_output=aln.bam \
#       --cores 4 --use-conda
# 流程内使用（输出常作为 samtools_sort_input 等下游输入）：
#   include: "modules/samtools/snakemake/samtools_sam_to_bam.smk"
#   rule all:
#       input: config["samtools_sort_output"]   # 经 samtools_sort.smk 串联
#
# config 契约（均有默认；独立运行时用 --config 覆盖）：
#   exec_mode                    : conda(默认) | docker | native
#   samtools.docker_image        : exec_mode=docker 时必填（镜像名）
#   samtools.samtools_bin        : exec_mode=native 时 samtools 路径（默认走 PATH）
#   samtools_sam_to_bam_input  : 必填 输入 SAM
#   samtools_sam_to_bam_output : 输出 BAM（默认 <输入去扩展名>.bam）
#   threads                    : 规则调度线程（默认 4；-@ 取 threads-1）

import os

config.setdefault("exec_mode", "conda")
config.setdefault("samtools_sam_to_bam_input", "")
config.setdefault("threads", 4)
_samtools_s2b_in = config["samtools_sam_to_bam_input"]
_samtools_s2b_stem = os.path.splitext(_samtools_s2b_in)[0] if _samtools_s2b_in else ""
config.setdefault("samtools_sam_to_bam_output", _samtools_s2b_stem + ".bam" if _samtools_s2b_stem else "")
_sam = config.setdefault("samtools", {})
_sam.setdefault("docker_image", "")
_sam.setdefault("samtools_bin", "samtools")

rule samtools_sam_to_bam:
    """samtools view -b：SAM -> BAM 格式转换（无过滤）。"""
    input:
        sam=config["samtools_sam_to_bam_input"]
    output:
        bam=temp(config["samtools_sam_to_bam_output"])
    conda: "samtools.yaml"
    log:
        os.path.join(os.path.dirname(config["samtools_sam_to_bam_output"]), "samtools_sam_to_bam.log")
    threads:
        config["threads"]
    message:
        "samtools view -b: {input.sam} -> {output.bam}"
    script: "samtools_sam_to_bam.py"
