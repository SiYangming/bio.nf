# td2_predict.smk —— TD2.Predict 单规则（Snakemake）
#
# 环境：同目录 td2.yaml（conda 相对本文件目录解析）；wrapper：同目录 td2_predict.py。
# 设计：config 驱动、单样本通用流程；输入 = td2_longorfs.smk 的产物目录。
#
# 独立运行示例（需先有 longorfs 产物，或用 --config 指向现成目录）：
#   snakemake -s modules/td2/snakemake/td2_predict.smk \
#       --config td2_input_fasta=transcripts.fa td2_outdir=td2_out \
#       --cores 4 --use-conda
# 流程内使用：
#   include: "modules/td2/snakemake/td2_longorfs.smk"
#   include: "modules/td2/snakemake/td2_predict.smk"
#   rule all:
#       input: os.path.join(config["td2_outdir"], "predict")  # directory 目标
#
# config 契约（longorfs/predict 两文件共用；独立运行时用 --config 覆盖）：
#   exec_mode                  : conda(默认) | docker | native
#   td2.docker_image           : exec_mode=docker 时必填（镜像名）
#   td2.predict_bin            : exec_mode=native 时的 TD2.Predict 路径（默认 TD2.Predict，走 PATH）
#   td2.retain_mmseqs_hits     : 可选 mmseqs .m8 证据文件
#   td2.retain_blastp_hits     : 可选 blastp -outfmt 6 证据文件
#   td2.retain_hmmer_hits      : 可选 hmmscan Pfam domain table 证据文件
#   td2.predict_extra_params   : 透传 extra，如 "--psauron-all-frame" / "--all-good"
#   td2_input_fasta            : 必填 输入转录本 FASTA（明文，与 longorfs 一致）
#   td2_outdir                 : 输出根（默认 td2_out；predict 产物在 <outdir>/predict/）
#   threads                    : 规则调度线程（默认 4）
#
# 产物命名：<fasta 文件名>.TD2.{pep,gff3,cds,bed}（与 TD2.Predict 前缀一致），位于 <outdir>/predict/。

import os

config.setdefault("exec_mode", "conda")
config.setdefault("td2_input_fasta", "")
config.setdefault("td2_outdir", "td2_out")
config.setdefault("threads", 4)
_td2 = config.setdefault("td2", {})
_td2.setdefault("docker_image", "")
_td2.setdefault("predict_bin", "TD2.Predict")
_td2.setdefault("retain_mmseqs_hits", "")
_td2.setdefault("retain_blastp_hits", "")
_td2.setdefault("retain_hmmer_hits", "")
_td2.setdefault("predict_extra_params", "")

_td2_longorfs_dir = os.path.join(config["td2_outdir"], "longorfs")
_td2_predict_dir = os.path.join(config["td2_outdir"], "predict")
_fasta_basename = os.path.basename(config["td2_input_fasta"])  # TD2 产物前缀 = 输入文件名

rule td2_predict:
    """TD2.Predict：基于 longorfs 候选 + 长度模型输出最终 CDS（产物在 <outdir>/predict/）。"""
    input:
        fasta=config["td2_input_fasta"],
        longorfs_dir=directory(_td2_longorfs_dir)
    output:
        dir=directory(_td2_predict_dir),
        pep=os.path.join(_td2_predict_dir, f"{_fasta_basename}.TD2.pep"),
        gff3=os.path.join(_td2_predict_dir, f"{_fasta_basename}.TD2.gff3"),
        cds=os.path.join(_td2_predict_dir, f"{_fasta_basename}.TD2.cds"),
        bed=os.path.join(_td2_predict_dir, f"{_fasta_basename}.TD2.bed")
    params:
        retain_mmseqs_hits=_td2["retain_mmseqs_hits"],
        retain_blastp_hits=_td2["retain_blastp_hits"],
        retain_hmmer_hits=_td2["retain_hmmer_hits"],
        extra=_td2["predict_extra_params"]
    conda: "td2.yaml"
    log:
        os.path.join(config["td2_outdir"], "logs", "td2_predict.log")
    threads:
        config["threads"]
    message:
        "TD2.Predict: {input.fasta} (longorfs {input.longorfs_dir}) -> {output.dir}"
    script:
        "td2_predict.py"
