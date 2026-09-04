# stringtie_merge.smk —— stringtie merge 单规则（Snakemake，td2 式）
#
# 环境：同目录 stringtie.yaml（conda 相对本文件目录解析）；wrapper：同目录 stringtie_merge.py。
# 设计：config 驱动、跨样本通用规则（GTF 列表 -> 非冗余合并 GTF），不依赖 workflow 的
#       SAMPLES / {sample} 目录层级。merge 的输入 GTF 列表文件（每行一个 GTF 路径）由流程层
#       汇总生成（例如对逐样本 stringtie_fix_gtf 产物 ls/find 写列表）。执行经同目录 wrapper
#       走 docker/native/conda 三模式分派：docker 用 stringtie.docker_image 镜像内 stringtie；
#       native 用 config 的 stringtie.stringtie_bin；conda 走 PATH（--use-conda 用同目录 yaml）。
#
# 独立运行示例：
#   snakemake -s modules/stringtie/snakemake/stringtie_merge.smk \
#       --config stringtie_gtf_list=gtf_list.txt \
#           stringtie_gtf_annotation=gencode.v49.annotation.gtf \
#       --cores 4 --use-conda
# 流程内使用：
#   include: "modules/stringtie/snakemake/stringtie_merge.smk"
#   rule all:
#       input: config["stringtie_merged_gtf"]
#
# config 契约（均有默认；独立运行时用 --config 覆盖）：
#   exec_mode                    : conda(默认) | docker | native
#   stringtie.docker_image       : exec_mode=docker 时必填（镜像名）
#   stringtie.stringtie_bin      : exec_mode=native 时 stringtie 路径（默认走 PATH）
#   stringtie_gtf_list           : 必填 输入 GTF 列表文件（每行一个 GTF 路径）
#   stringtie_merged_gtf         : 输出合并 GTF（默认 stringtie_out/merge/stringtie_merged_nonredundant.gtf）
#   stringtie_gtf_annotation     : 可选 参考注释 GTF（-G；空则不传）
#   stringtie_merge_label        : 合并转录本前缀标签 -l（默认 MSTRG）
#   stringtie_min_transcript_len : 最小转录本长度 -m（默认 200）
#   stringtie_extra_args         : 透传 stringtie 附加参数（默认空）
#   threads                      : 规则调度线程 -p（默认 4）

import os

config.setdefault("exec_mode", "conda")
_st = config.setdefault("stringtie", {})
_st.setdefault("docker_image", "")
_st.setdefault("stringtie_bin", "stringtie")

config.setdefault("stringtie_gtf_list", "")
config.setdefault("stringtie_gtf_annotation", "")
config.setdefault(
    "stringtie_merged_gtf",
    os.path.join("stringtie_out", "merge", "stringtie_merged_nonredundant.gtf"),
)
config.setdefault("stringtie_merge_label", "MSTRG")
config.setdefault("stringtie_min_transcript_len", 200)
config.setdefault("stringtie_extra_args", "")
config.setdefault("threads", 4)

_ann = config["stringtie_gtf_annotation"]
_gtf_arg = f"-G {_ann}" if _ann else ""

rule stringtie_merge:
    """stringtie --merge：多样本 GTF 列表 -> 非冗余合并 GTF。"""
    input:
        gtf_list=config["stringtie_gtf_list"]
    output:
        merged_gtf=config["stringtie_merged_gtf"]
    params:
        gtf_arg=_gtf_arg,
        label=config["stringtie_merge_label"],
        min_len=config["stringtie_min_transcript_len"],
        extra=config["stringtie_extra_args"]
    conda: "stringtie.yaml"
    log:
        os.path.join(os.path.dirname(config["stringtie_merged_gtf"]), "stringtie_merge.log")
    threads:
        config["threads"]
    message:
        "stringtie merge: {input.gtf_list} -> {output.merged_gtf}"
    script: "stringtie_merge.py"
