# samtools_sort.smk —— samtools sort 单规则（Snakemake，td2 式）
#
# 环境：同目录 samtools.yaml（conda 相对本文件目录解析）；wrapper：同目录 samtools_sort.py。
# 设计：config 驱动、单任务通用规则（BAM/SAM/CRAM -> sorted.bam），不依赖 workflow 的
#       SAMPLES / {sample} 层级 / config[paths]；由原聚合 samtools.smk（sam->sorted.bam+bai
#       流程版）与 samtools_riboseq.smk（bam->sorted.bam 版）的 sort 语义合并而来。sort 需
#       内存均摊（-m）+ 输出目录内临时前缀等逻辑，故按 AGENT「执行指令选择」保留 script。
#
# 独立运行示例：
#   snakemake -s modules/samtools/snakemake/samtools_sort.smk \
#       --config samtools_sort_input=aln.sam samtools_sort_output=aln.sorted.bam \
#       --cores 8 --use-conda
# 流程内使用（与 samtools_index.smk 串接：令 samtools_index_input == samtools_sort_output
#   即自动建立 sort -> index 依赖）：
#   include: "modules/samtools/snakemake/samtools_sort.smk"
#   include: "modules/samtools/snakemake/samtools_index.smk"
#   rule all:
#       input: config["samtools_index_output"]
#
# config 契约（均有默认；独立运行时用 --config 覆盖）：
#   exec_mode                    : conda(默认) | docker | native
#   samtools.docker_image        : exec_mode=docker 时必填（镜像名）
#   samtools.samtools_bin        : exec_mode=native 时 samtools 路径（默认走 PATH）
#   samtools.sort_extra_params   : 透传 sort 附加参数（如 "-n" 按 read name 排序）
#   samtools.mem_mb              : 总内存预算（默认 8192；wrapper 按线程均摊为 -m）
#   samtools.mem_overhead_factor : 留给 samtools 自身的开销比例（默认 0.1）
#   samtools_sort_input          : 必填 输入 BAM/SAM/CRAM
#   samtools_sort_output         : 输出 sorted BAM（默认 <输入去扩展名>.sorted.bam）
#   threads                      : 规则调度线程（默认 4；sort 建议 8）

import os

config.setdefault("exec_mode", "conda")
config.setdefault("samtools_sort_input", "")
config.setdefault("threads", 4)
_samtools_sort_in = config["samtools_sort_input"]
_samtools_sort_stem = os.path.splitext(_samtools_sort_in)[0] if _samtools_sort_in else ""
config.setdefault("samtools_sort_output", _samtools_sort_stem + ".sorted.bam" if _samtools_sort_stem else "")
_sam = config.setdefault("samtools", {})
_sam.setdefault("docker_image", "")
_sam.setdefault("samtools_bin", "samtools")
_sam.setdefault("sort_extra_params", "")
_sam.setdefault("mem_mb", 8192)
_sam.setdefault("mem_overhead_factor", 0.1)

rule samtools_sort:
    """samtools sort：对 BAM/SAM/CRAM 按坐标（或 -n 按 read name）排序。"""
    input:
        bam=config["samtools_sort_input"]
    output:
        bam=config["samtools_sort_output"]
    params:
        extra=_sam["sort_extra_params"],
        mem_overhead_factor=_sam["mem_overhead_factor"]
    resources:
        mem_mb=_sam["mem_mb"]
    conda: "samtools.yaml"
    log:
        os.path.join(os.path.dirname(config["samtools_sort_output"]), "samtools_sort.log")
    threads:
        config["threads"]
    message:
        "samtools sort: {input.bam} -> {output.bam}"
    script: "samtools_sort.py"
