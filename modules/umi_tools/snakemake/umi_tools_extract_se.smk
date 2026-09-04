# umi_tools_extract_se.smk —— umi_tools extract（SE）单规则（Snakemake，td2 式）
#
# 环境：同目录 umi_tools.yaml（conda 相对本文件目录解析）；wrapper：同目录 umi_tools_extract.py。
# 设计：config 驱动、单样本通用，不依赖 workflow 的 samples / config[paths] 层级。
# 说明：umi_tools extract 只有 SE/PE 两种输入形态（同一 wrapper），故拆为
# umi_tools_extract_se.smk / umi_tools_extract_pe.smk（每文件一规则）。
#
# 独立运行示例：
#   snakemake -s modules/umi_tools/snakemake/umi_tools_extract_se.smk \
#       --config umi_input_fastq=reads.fastq.gz 'umi_tools.bc_pattern=NNNNNNNN' \
#       umi_output_fastq=reads_umi.fastq.gz --cores 4 --use-conda
# 流程内使用（可分别 include SE/PE/dedup 单规则文件）：
#   include: "modules/umi_tools/snakemake/umi_tools_extract_se.smk"
#   include: "modules/umi_tools/snakemake/umi_tools_extract_pe.smk"
#   include: "modules/umi_tools/snakemake/umi_tools_dedup.smk"
#
# config 契约（均有默认；独立运行时用 --config 覆盖）：
#   exec_mode                  : conda(默认) | docker | native
#   umi_tools.docker_image     : exec_mode=docker 时必填（镜像名）
#   umi_tools.umi_tools_bin    : exec_mode=native 时的 umi_tools 路径（默认 umi_tools，走 PATH）
#   umi_tools.bc_pattern       : UMI 条形码模式（透传 --bc-pattern，如 NNNNNNNN）
#   umi_tools.extract_method   : extract 方法 string|regex（透传 --extract-method）
#   umi_tools.extra_params     : 透传 extra（如 "--bc-pattern2=NNNNNNNN --3prime"）
#   umi_input_fastq            : 必填 输入 FASTQ（SE 的 R1）
#   umi_output_fastq           : 输出 UMI 标记 FASTQ（默认 umi_out/umi_extract.fastq.gz）
#   threads                    : 规则调度线程（默认 4）

import os

config.setdefault("exec_mode", "conda")
config.setdefault("umi_input_fastq", "")
config.setdefault("umi_output_fastq", os.path.join("umi_out", "umi_extract.fastq.gz"))
config.setdefault("threads", 4)
_ut = config.setdefault("umi_tools", {})
_ut.setdefault("docker_image", "")
_ut.setdefault("umi_tools_bin", "umi_tools")
_ut.setdefault("bc_pattern", "")
_ut.setdefault("extract_method", "")
_ut.setdefault("extra_params", "")

rule umi_tools_extract_se:
    """umi_tools extract（SE）：按条形码模式从单端 reads 提取 UMI 并写入 read 头。"""
    input:
        fastq1=config["umi_input_fastq"]
    output:
        fastq=config["umi_output_fastq"]
    params:
        extract_method=_ut["extract_method"],
        bc_pattern=_ut["bc_pattern"],
        extra=_ut["extra_params"]
    conda: "umi_tools.yaml"
    log:
        os.path.join(os.path.dirname(config["umi_output_fastq"]), "umi_tools_extract_se.log")
    threads:
        config["threads"]
    message:
        "umi_tools extract (SE): {input.fastq1} -> {output.fastq}"
    script:
        "umi_tools_extract.py"
