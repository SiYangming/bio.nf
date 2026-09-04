# samtools_view.smk —— samtools view 单规则（Snakemake，td2 式）
#
# 环境：同目录 samtools.yaml（conda 相对本文件目录解析）；wrapper：同目录 samtools_view.py。
# 设计：config 驱动、单任务通用规则（BAM -> 过滤/转换后输出），不依赖 workflow 的 samples /
#       config[paths]；单条命令按 AGENT「执行指令选择」经 script wrapper（samtools_view.py）
#       做 docker/native/conda 三模式分派（exec_mode），命令串与原 shell 语义一致
#       （region/extra + -@ threads-1）。
#
# 独立运行示例：
#   snakemake -s modules/samtools/snakemake/samtools_view.smk \
#       --config samtools_view_input=aln.bam samtools_view_output=aln_view.bam \
#       'samtools.view_extra_params=-F 1796 -q 30' samtools_view_region=chr1:1000-2000 \
#       --cores 4 --use-conda
# 流程内使用：
#   include: "modules/samtools/snakemake/samtools_view.smk"
#   rule all:
#       input: config["samtools_view_output"]
#
# config 契约（均有默认；独立运行时用 --config 覆盖）：
#   exec_mode                    : conda(默认) | docker | native
#   samtools.docker_image        : exec_mode=docker 时必填（镜像名）
#   samtools.samtools_bin        : exec_mode=native 时 samtools 路径（默认走 PATH）
#   samtools.view_extra_params  : 透传 view 附加参数（如 "-F 1796 -q 30 -b"；勿重复传 -o）
#   samtools_view_input         : 必填 输入 BAM/SAM/CRAM
#   samtools_view_output        : 输出（默认 <输入去扩展名>_view.bam；输出格式按扩展名推断）
#   samtools_view_region         : 可选区域字符串（如 "chr1:1000-2000"；空则全文件）
#   threads                     : 规则调度线程（默认 4；-@ 取 threads-1）

import os

config.setdefault("exec_mode", "conda")
config.setdefault("samtools_view_input", "")
config.setdefault("samtools_view_region", "")
config.setdefault("threads", 4)
_samtools_view_in = config["samtools_view_input"]
_samtools_view_stem = os.path.splitext(_samtools_view_in)[0] if _samtools_view_in else ""
config.setdefault("samtools_view_output", _samtools_view_stem + "_view.bam" if _samtools_view_stem else "")
_sam = config.setdefault("samtools", {})
_sam.setdefault("docker_image", "")
_sam.setdefault("samtools_bin", "samtools")
_sam.setdefault("view_extra_params", "")

rule samtools_view:
    """samtools view：按 FLAG/MAPQ/region 过滤，或做 SAM/BAM/CRAM 格式转换。"""
    input:
        bam=config["samtools_view_input"]
    output:
        out=config["samtools_view_output"]
    params:
        extra=_sam["view_extra_params"],
        region=config["samtools_view_region"]
    conda: "samtools.yaml"
    log:
        os.path.join(os.path.dirname(config["samtools_view_output"]), "samtools_view.log")
    threads:
        config["threads"]
    message:
        "samtools view: {input.bam} -> {output.out}"
    script: "samtools_view.py"
