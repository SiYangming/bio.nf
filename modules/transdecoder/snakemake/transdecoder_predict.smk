# transdecoder_predict.smk —— TransDecoder.Predict 单规则（Snakemake）
#
# 环境：同目录 transdecoder.yaml（conda 相对本文件目录解析）；wrapper：同目录 transdecoder_predict.py。
# 设计：config 驱动、单样本通用流程（td2 式样板）；输入 = transdecoder_longorfs.smk 产物目录。
#
# 独立运行示例（需先有 longorfs 产物）：
#   snakemake -s modules/transdecoder/snakemake/transdecoder_predict.smk \
#       --config transdecoder_input_fasta=transcripts.fa transdecoder_outdir=td_out \
#       --cores 4 --use-conda
# 流程内使用：
#   include: "modules/transdecoder/snakemake/transdecoder_longorfs.smk"
#   include: "modules/transdecoder/snakemake/transdecoder_predict.smk"
#   rule all:
#       input: os.path.join(config["transdecoder_outdir"], "predict")  # directory 目标
#
# TransDecoder.Predict -t <fa> -O <predict_dir> 产出 <predict_dir>/<fa>.transdecoder.{pep,gff3,cds,bed}
# （wrapper 先在建目录内放置 <fa>.transdecoder_dir 供 Predict 使用，结束后清理）。
#
# config 契约（与 transdecoder_longorfs.smk 共用；独立运行时用 --config 覆盖）：
#   exec_mode                          : conda(默认) | docker | native
#   transdecoder.docker_image          : exec_mode=docker 时必填（镜像名）
#   transdecoder.predict_bin           : exec_mode=native 时的 TransDecoder.Predict 路径（默认走 PATH）
#   transdecoder.retain_pfam_hits      : 可选 pfam.domtblout（--retain_pfam_hits）
#   transdecoder.retain_blastp_hits    : 可选 blastp -outfmt 6 结果（--retain_blastp_hits）
#   transdecoder.predict_extra_params  : 透传 extra，如 "--no_refine_starts"
#   transdecoder_input_fasta           : 必填 输入转录本 FASTA（明文，与 longorfs 一致）
#   transdecoder_outdir                : 输出根（默认 transdecoder_out；predict 产物在 <outdir>/predict/）
#   threads                            : 规则调度线程（默认 4）

import os

config.setdefault("exec_mode", "conda")
config.setdefault("transdecoder_input_fasta", "")
config.setdefault("transdecoder_outdir", "transdecoder_out")
config.setdefault("threads", 4)
_td = config.setdefault("transdecoder", {})
_td.setdefault("docker_image", "")
_td.setdefault("predict_bin", "TransDecoder.Predict")
_td.setdefault("retain_pfam_hits", "")
_td.setdefault("retain_blastp_hits", "")
_td.setdefault("predict_extra_params", "")

_td_longorfs_dir = os.path.join(config["transdecoder_outdir"], "longorfs")
_td_predict_dir = os.path.join(config["transdecoder_outdir"], "predict")
_fasta_basename = os.path.basename(config["transdecoder_input_fasta"])   # TransDecoder 产物名前缀

rule transdecoder_predict:
    """TransDecoder.Predict：基于 longorfs 候选做最终 CDS 预测（产物在 <outdir>/predict/）。"""
    input:
        fasta=config["transdecoder_input_fasta"],
        longorfs_dir=directory(_td_longorfs_dir)
    output:
        dir=directory(_td_predict_dir),
        pep=os.path.join(_td_predict_dir, f"{_fasta_basename}.transdecoder.pep"),
        gff3=os.path.join(_td_predict_dir, f"{_fasta_basename}.transdecoder.gff3"),
        cds=os.path.join(_td_predict_dir, f"{_fasta_basename}.transdecoder.cds"),
        bed=os.path.join(_td_predict_dir, f"{_fasta_basename}.transdecoder.bed")
    params:
        retain_pfam_hits=_td["retain_pfam_hits"],
        retain_blastp_hits=_td["retain_blastp_hits"],
        extra=_td["predict_extra_params"]
    conda: "transdecoder.yaml"
    log:
        os.path.join(config["transdecoder_outdir"], "logs", "transdecoder_predict.log")
    threads:
        config["threads"]
    message:
        "TransDecoder.Predict: {input.fasta} (longorfs {input.longorfs_dir}) -> {output.dir}"
    script:
        "transdecoder_predict.py"
