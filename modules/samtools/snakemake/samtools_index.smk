# samtools_index.smk —— samtools index 单规则（Snakemake，td2 式）
#
# 环境：同目录 samtools.yaml（conda 相对本文件目录解析）；wrapper：同目录 samtools_index.py。
# 设计：config 驱动、单任务通用规则（sorted BAM -> .bai），不依赖 workflow 的 samples /
#       config[paths]；单条命令按 AGENT「执行指令选择」经 script wrapper（samtools_index.py）
#       做 docker/native/conda 三模式分派（exec_mode），命令串与原 shell 语义一致
#       （-@ threads-1 + index_extra_params）。
#
# 独立运行示例：
#   snakemake -s modules/samtools/snakemake/samtools_index.smk \
#       --config samtools_index_input=aln.sorted.bam samtools_index_output=aln.sorted.bam.bai \
#       --cores 4 --use-conda
# 流程内使用（sort 产物直接接 index：令 samtools_index_input == samtools_sort_output）：
#   include: "modules/samtools/snakemake/samtools_sort.smk"
#   include: "modules/samtools/snakemake/samtools_index.smk"
#   rule all:
#       input: config["samtools_index_output"]
#
# config 契约（均有默认；独立运行时用 --config 覆盖）：
#   exec_mode                    : conda(默认) | docker | native
#   samtools.docker_image        : exec_mode=docker 时必填（镜像名）
#   samtools.samtools_bin        : exec_mode=native 时 samtools 路径（默认走 PATH）
#   samtools.index_extra_params : 透传 index 附加参数（如 "-c" 生成 .csi；此时请自行指定输出名）
#   samtools_index_input        : 必填 输入 sorted BAM（或 CRAM）
#   samtools_index_output       : 输出索引（默认 <输入>.bai）
#   threads                     : 规则调度线程（默认 4；-@ 取 threads-1）

import os

config.setdefault("exec_mode", "conda")
config.setdefault("samtools_index_input", "")
config.setdefault("threads", 4)
_samtools_index_in = config["samtools_index_input"]
config.setdefault("samtools_index_output", _samtools_index_in + ".bai" if _samtools_index_in else "")
_sam = config.setdefault("samtools", {})
_sam.setdefault("docker_image", "")
_sam.setdefault("samtools_bin", "samtools")
_sam.setdefault("index_extra_params", "")

rule samtools_index:
    """samtools index：为排序后 BAM 建立 .bai 索引（额外线程 -@ = threads-1）。"""
    input:
        bam=config["samtools_index_input"]
    output:
        bai=config["samtools_index_output"]
    params:
        extra=_sam["index_extra_params"]
    conda: "samtools.yaml"
    log:
        os.path.join(os.path.dirname(config["samtools_index_output"]), "samtools_index.log")
    threads:
        config["threads"]
    message:
        "samtools index: {input.bam} -> {output.bai}"
    script: "samtools_index.py"
