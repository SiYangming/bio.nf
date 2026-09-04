# orffinder.smk —— ORFfinder 单规则（Snakemake）
#
# 环境：同目录 orffinder.yaml（conda 相对本文件目录解析）；wrapper：同目录 orffinder.py。
# 设计：config 驱动、单样本通用流程，不依赖 workflow 的 SAMPLES / {sample} 目录层级。
#
# 独立运行示例：
#   snakemake -s modules/orffinder/snakemake/orffinder.smk \
#       --config orffinder_input_fasta=transcripts.fa orffinder_outdir=orffinder_out \
#       --cores 4 --use-conda
# 流程内使用：
#   include: "modules/orffinder/snakemake/orffinder.smk"
#   rule all:
#       input: os.path.join(config["orffinder_outdir"], <fasta_stem><suffix>)
#
# 产物命名：<fasta 文件名（去 .gz / 扩展名）><suffix>，suffix 依 outfmt（suffix_map）：
#   outfmt 0 -> _orf.fa；1 -> _cds.fa；2 -> .asn1（默认）；3 -> .ft
#
# config 契约（均有默认；独立运行时用 --config 覆盖）：
#   exec_mode                 : conda(默认) | docker | native
#   orffinder.docker_image    : exec_mode=docker 时必填（镜像名）
#   orffinder.orffinder_bin   : exec_mode=native 时的 ORFfinder 路径（默认 ORFfinder，走 PATH）
#   orffinder.outfmt          : 输出格式 0/1/2/3（默认 2，Text ASN.1）
#   orffinder.suffix_map      : outfmt -> 输出后缀映射（默认 {0:_orf.fa,1:_cds.fa,2:.asn1,3:.ft}）
#   orffinder.extra_params    : 透传 extra，如 "-g 1 -s 2 -ml 30 -strand both"
#   orffinder_input_fasta     : 必填 输入核酸 FASTA（.gz 时 wrapper 自动解压到执行目录）
#   orffinder_outdir          : 输出目录（默认 orffinder_out；产物在 <outdir>/）
#   threads                   : 规则调度线程（默认 4）

import os

config.setdefault("exec_mode", "conda")
config.setdefault("orffinder_input_fasta", "")
config.setdefault("orffinder_outdir", "orffinder_out")
config.setdefault("threads", 4)
_of = config.setdefault("orffinder", {})
_of.setdefault("docker_image", "")
_of.setdefault("orffinder_bin", "ORFfinder")
_of.setdefault("outfmt", 2)
_of.setdefault("suffix_map", {0: "_orf.fa", 1: "_cds.fa", 2: ".asn1", 3: ".ft"})
_of.setdefault("extra_params", "")
_of_outfmt = int(_of["outfmt"])  # config 数字可能以字符串传入（--config key=2）

_fasta_basename = os.path.basename(config["orffinder_input_fasta"])
if _fasta_basename.endswith(".gz"):
    _fasta_basename = _fasta_basename[: -len(".gz")]
_fasta_stem = os.path.splitext(_fasta_basename)[0]
_orffinder_output = os.path.join(
    config["orffinder_outdir"], _fasta_stem + _of["suffix_map"][_of_outfmt]
)

rule orffinder:
    """ORFfinder：在核酸序列中查找 ORF（产物 <outdir>/<fasta_stem><suffix>）。"""
    input:
        fasta=config["orffinder_input_fasta"]
    output:
        file=_orffinder_output
    params:
        outfmt=_of_outfmt,
        extra=_of["extra_params"]
    conda: "orffinder.yaml"
    log:
        os.path.join(config["orffinder_outdir"], "logs", "orffinder.log")
    threads:
        config["threads"]
    message:
        "ORFfinder: {input.fasta} -> {output.file} (outfmt {params.outfmt})"
    script:
        "orffinder.py"
