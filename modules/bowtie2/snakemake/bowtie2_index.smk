# bowtie2_index.smk —— bowtie2-build 索引 单规则（Snakemake）
#
# 环境：同目录 bowtie2.yaml（conda 相对本文件目录解析）；wrapper：同目录 bowtie2_index.py。
# 设计：config 驱动、通用流程（td2 式）；不依赖 workflow 的 SAMPLES / riboseq 流程上下文。
#
# 独立运行示例：
#   snakemake -s modules/bowtie2/snakemake/bowtie2_index.smk \
#       --config bowtie2_input_fasta=ref.fa bowtie2_index_prefix=bt2_index/bowtie2 \
#       --cores 8 --use-conda
# 流程内使用（与 bowtie2_align.smk 共用同一 bowtie2_index_prefix 即自动建立依赖）：
#   include: "modules/bowtie2/snakemake/bowtie2_index.smk"
#   include: "modules/bowtie2/snakemake/bowtie2_align.smk"
#
# config 契约（均有默认；独立运行时用 --config 覆盖）：
#   exec_mode                 : conda(默认) | docker | native
#   bowtie2.docker_image      : exec_mode=docker 时必填（镜像名）
#   bowtie2.index_bin         : exec_mode=native 时 bowtie2-build 路径（默认走 PATH）
#   bowtie2.bowtie2_build_params : 透传 bowtie2-build 附加参数
#   bowtie2_input_fasta       : 必填 参考基因组 FASTA
#   bowtie2_index_prefix      : 索引输出前缀（默认 bowtie2_out/index/bowtie2；产物 *.bt2 同前缀）
#   threads                   : 规则调度线程（默认 8）

import os

config.setdefault("exec_mode", "conda")
config.setdefault("bowtie2_input_fasta", "")
config.setdefault("bowtie2_index_prefix", os.path.join("bowtie2_out", "index", "bowtie2"))
config.setdefault("threads", 8)
_b2 = config.setdefault("bowtie2", {})
_b2.setdefault("docker_image", "")
_b2.setdefault("index_bin", "bowtie2-build")
_b2.setdefault("bowtie2_build_params", "")

rule bowtie2_index:
    """bowtie2-build：为参考基因组构建 bowtie2 索引（*.bt2）。"""
    input:
        ref=config["bowtie2_input_fasta"]
    output:
        multiext(
            config["bowtie2_index_prefix"],
            ".1.bt2", ".2.bt2", ".3.bt2", ".4.bt2", ".rev.1.bt2", ".rev.2.bt2",
        )
    params:
        extra=_b2["bowtie2_build_params"]
    conda: "bowtie2.yaml"
    log:
        os.path.join(os.path.dirname(config["bowtie2_index_prefix"]), "bowtie2_index.log")
    threads:
        config["threads"]
    message:
        "bowtie2-build: {input.ref} -> {output}"
    script:
        "bowtie2_index.py"
