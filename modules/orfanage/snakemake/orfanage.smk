# orfanage.smk —— ORFanage 单规则（Snakemake）
#
# 环境：同目录 orfanage.yaml（conda 相对本文件目录解析）；wrapper：同目录 orfanage.py。
# 设计：config 驱动、单样本通用流程，不依赖 workflow 的 SAMPLES / {sample} 目录层级。
# query 的 GFF3 由 wrapper 在 query_dir 内自动选取 *.transdecoder.gff3（回退 *.gff3）。
#
# 独立运行示例：
#   snakemake -s modules/orfanage/snakemake/orfanage.smk \
#       --config orfanage_input_query_dir=predict orfanage_templates=tpl.fa orfanage_outdir=orfanage_out \
#       --cores 4 --use-conda
# 流程内使用：
#   include: "modules/orfanage/snakemake/orfanage.smk"
#   rule all:
#       input: os.path.join(config["orfanage_outdir"], "orfanage.gtf")
#
# config 契约（均有默认；独立运行时用 --config 覆盖）：
#   exec_mode                     : conda(默认) | docker | native
#   orfanage.docker_image         : exec_mode=docker 时必填（镜像名）
#   orfanage.orfanage_bin         : exec_mode=native 时的 orfanage 路径（默认 orfanage，走 PATH）
#   orfanage.reference            : 可选 参考序列 FASTA
#   orfanage.templates            : 必填 模板 FASTA（一个或多个，空格分隔的字符串或列表）
#   orfanage.cleanq/cleant/rescue/use_id/non_aug/keep_all_cds/keep_cds_if_not_found/spliced_overhang
#                                 : 可选布尔开关（默认 false）
#   orfanage.lpi/ilpi/mlpi        : 可选蛋白长度阈值（默认 -1 禁用）
#   orfanage.minlen/overhang      : 可选整数阈值（默认 0 不启用）
#   orfanage.mode/stats           : 可选字符串参数（默认空）
#   orfanage.extra_params         : 透传 extra，如 "--longest-only"
#   orfanage_input_query_dir      : 必填 预测 GFF3 所在目录（glob *.transdecoder.gff3 -> *.gff3）
#   orfanage_outdir               : 输出根（默认 orfanage_out；GTF 在 <outdir>/orfanage.gtf）
#   threads                       : 规则调度线程（默认 4）

import os

config.setdefault("exec_mode", "conda")
config.setdefault("orfanage_input_query_dir", "")
config.setdefault("orfanage_outdir", "orfanage_out")
config.setdefault("threads", 4)
_of = config.setdefault("orfanage", {})
_of.setdefault("docker_image", "")
_of.setdefault("orfanage_bin", "orfanage")
_of.setdefault("reference", "")
_of.setdefault("templates", [])
_of.setdefault("extra_params", "")
for _k in ("cleanq", "cleant", "rescue", "use_id", "non_aug",
           "keep_all_cds", "keep_cds_if_not_found", "spliced_overhang"):
    _of.setdefault(_k, False)
for _k in ("lpi", "ilpi", "mlpi"):
    _of.setdefault(_k, -1)
for _k in ("minlen", "overhang"):
    _of.setdefault(_k, 0)
for _k in ("mode", "stats"):
    _of.setdefault(_k, "")

_of_gtf = os.path.join(config["orfanage_outdir"], "orfanage.gtf")

rule orfanage:
    """ORFanage：按参考/模板合并注释预测 ORF（GFF3 -> GTF，产物 <outdir>/orfanage.gtf）。"""
    input:
        query_dir=directory(config["orfanage_input_query_dir"])
    output:
        gtf=_of_gtf
    params:
        reference=_of["reference"],
        templates=_of["templates"],
        cleanq=_of["cleanq"],
        cleant=_of["cleant"],
        rescue=_of["rescue"],
        use_id=_of["use_id"],
        non_aug=_of["non_aug"],
        keep_all_cds=_of["keep_all_cds"],
        keep_cds_if_not_found=_of["keep_cds_if_not_found"],
        spliced_overhang=_of["spliced_overhang"],
        lpi=_of["lpi"],
        ilpi=_of["ilpi"],
        mlpi=_of["mlpi"],
        minlen=_of["minlen"],
        mode=_of["mode"],
        stats=_of["stats"],
        overhang=_of["overhang"],
        extra=_of["extra_params"]
    conda: "orfanage.yaml"
    log:
        os.path.join(config["orfanage_outdir"], "logs", "orfanage.log")
    threads:
        config["threads"]
    message:
        "ORFanage: {input.query_dir} -> {output.gtf}"
    script:
        "orfanage.py"
