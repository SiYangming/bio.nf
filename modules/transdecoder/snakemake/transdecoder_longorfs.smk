# transdecoder_longorfs.smk —— TransDecoder.LongOrfs 单规则（Snakemake）
#
# 环境：同目录 transdecoder.yaml（conda 相对本文件目录解析）；wrapper：同目录 transdecoder_longorfs.py。
# 设计：config 驱动、单样本通用流程（td2 式样板），不依赖 workflow 的 SAMPLES / {sample} 层级。
#
# 独立运行示例：
#   snakemake -s modules/transdecoder/snakemake/transdecoder_longorfs.smk \
#       --config transdecoder_input_fasta=transcripts.fa transdecoder_outdir=td_out \
#       --cores 4 --use-conda
# 流程内使用（配合 transdecoder_predict.smk）：
#   include: "modules/transdecoder/snakemake/transdecoder_longorfs.smk"
#   include: "modules/transdecoder/snakemake/transdecoder_predict.smk"
#
# TransDecoder.LongOrfs -t <fa> -O <longorfs_dir> 会生成 <longorfs_dir>/<fa>.transdecoder_dir/，
# 内部含 longest_orfs.{pep,gff3,cds}；predict 规则以其为输入目录。
#
# config 契约（均有默认；独立运行时用 --config 覆盖）：
#   exec_mode                         : conda(默认) | docker | native
#   transdecoder.docker_image         : exec_mode=docker 时必填（镜像名）
#   transdecoder.longorfs_bin         : exec_mode=native 时的 TransDecoder.LongOrfs 路径（默认走 PATH）
#   transdecoder.gene_trans_map       : 可选 gene->transcript 映射文件
#   transdecoder.longorfs_extra_params: 透传 extra，如 "-m 50 -G Universal -S --complete_orfs_only"
#   transdecoder_input_fasta          : 必填 输入转录本 FASTA（明文，不支持 .gz）
#   transdecoder_outdir               : 输出根（默认 transdecoder_out；longorfs 在 <outdir>/longorfs/）
#   threads                           : 规则调度线程（默认 4）

import os

config.setdefault("exec_mode", "conda")
config.setdefault("transdecoder_input_fasta", "")
config.setdefault("transdecoder_outdir", "transdecoder_out")
config.setdefault("threads", 4)
_td = config.setdefault("transdecoder", {})
_td.setdefault("docker_image", "")
_td.setdefault("longorfs_bin", "TransDecoder.LongOrfs")
_td.setdefault("gene_trans_map", "")
_td.setdefault("longorfs_extra_params", "")

_td_longorfs_dir = os.path.join(config["transdecoder_outdir"], "longorfs")
_fasta_basename = os.path.basename(config["transdecoder_input_fasta"])   # TransDecoder 内部目录名前缀
_td_dir_name = f"{_fasta_basename}.transdecoder_dir"

rule transdecoder_longorfs:
    """TransDecoder.LongOrfs：从转录本 FASTA 提取候选最长 ORF（产物在 <outdir>/longorfs/）。"""
    input:
        fasta=config["transdecoder_input_fasta"]
    output:
        dir=directory(_td_longorfs_dir),
        pep=os.path.join(_td_longorfs_dir, _td_dir_name, "longest_orfs.pep"),
        gff3=os.path.join(_td_longorfs_dir, _td_dir_name, "longest_orfs.gff3"),
        cds=os.path.join(_td_longorfs_dir, _td_dir_name, "longest_orfs.cds")
    params:
        gene_trans_map=_td["gene_trans_map"],
        extra=_td["longorfs_extra_params"]
    conda: "transdecoder.yaml"
    log:
        os.path.join(config["transdecoder_outdir"], "logs", "transdecoder_longorfs.log")
    threads:
        config["threads"]
    message:
        "TransDecoder.LongOrfs: {input.fasta} -> {output.dir}"
    script:
        "transdecoder_longorfs.py"
