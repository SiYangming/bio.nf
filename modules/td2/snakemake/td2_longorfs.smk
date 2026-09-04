# td2_longorfs.smk —— TD2.LongOrfs 单规则（Snakemake）
#
# 环境：同目录 td2.yaml（conda 相对本文件目录解析）；wrapper：同目录 td2_longorfs.py。
# 设计：config 驱动、单样本通用流程，不依赖 workflow 的 SAMPLES / {sample} 目录层级。
#
# 独立运行示例：
#   snakemake -s modules/td2/snakemake/td2_longorfs.smk \
#       --config td2_input_fasta=transcripts.fa td2_outdir=td2_out \
#       --cores 4 --use-conda
# 流程内使用（配合 td2_predict.smk）：
#   include: "modules/td2/snakemake/td2_longorfs.smk"
#   include: "modules/td2/snakemake/td2_predict.smk"
#   rule all:
#       input: os.path.join(config["td2_outdir"], "predict", ...TD2.*)  # 见 td2_predict.smk 头注
#
# config 契约（均有默认；独立运行时用 --config 覆盖）：
#   exec_mode                  : conda(默认) | docker | native
#   td2.docker_image           : exec_mode=docker 时必填（镜像名）
#   td2.longorfs_bin           : exec_mode=native 时的 TD2.LongOrfs 路径（默认 TD2.LongOrfs，走 PATH）
#   td2.gene_trans_map         : 可选 gene->transcript 映射文件
#   td2.longorfs_extra_params  : 透传 extra，如 "-m 90 -M 90 -G 1 -S --alt-start --all-stopless"
#   td2_input_fasta            : 必填 输入转录本 FASTA（明文，不支持 .gz）
#   td2_outdir                 : 输出根（默认 td2_out；longorfs 产物在 <outdir>/longorfs/）
#   threads                    : 规则调度线程（默认 4）

import os

config.setdefault("exec_mode", "conda")
config.setdefault("td2_input_fasta", "")
config.setdefault("td2_outdir", "td2_out")
config.setdefault("threads", 4)
_td2 = config.setdefault("td2", {})
_td2.setdefault("docker_image", "")
_td2.setdefault("longorfs_bin", "TD2.LongOrfs")
_td2.setdefault("gene_trans_map", "")
_td2.setdefault("longorfs_extra_params", "")

_td2_longorfs_dir = os.path.join(config["td2_outdir"], "longorfs")

rule td2_longorfs:
    """TD2.LongOrfs：从转录本 FASTA 提取候选最长 ORF（产物在 <outdir>/longorfs/）。"""
    input:
        fasta=config["td2_input_fasta"]
    output:
        dir=directory(_td2_longorfs_dir),
        pep=os.path.join(_td2_longorfs_dir, "longest_orfs.pep"),
        gff3=os.path.join(_td2_longorfs_dir, "longest_orfs.gff3"),
        cds=os.path.join(_td2_longorfs_dir, "longest_orfs.cds")
    params:
        gene_trans_map=_td2["gene_trans_map"],
        extra=_td2["longorfs_extra_params"]
    conda: "td2.yaml"
    log:
        os.path.join(config["td2_outdir"], "logs", "td2_longorfs.log")
    threads:
        config["threads"]
    message:
        "TD2.LongOrfs: {input.fasta} -> {output.dir}"
    script:
        "td2_longorfs.py"
