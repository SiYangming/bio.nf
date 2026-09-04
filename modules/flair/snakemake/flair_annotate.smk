# flair_annotate.smk —— flair annotate 单规则（Snakemake，td2 式）
#
# 环境：同目录 flair.yaml（conda 相对本文件目录解析）；wrapper：同目录 flair_annotate.py。
# 设计：config 驱动、单任务通用规则（BED12 + GTF -> 带基因注释 BED），不依赖 workflow 的
#       SAMPLES / {sample} / output_dir 层级。identify_gene_isoform 为单条命令、无额外
#       逻辑，docker/native/conda 三模式统一走同目录 wrapper flair_annotate.py（分派经
#       共享 modules/docker_wrapper.py 的 docker_wrapper_binary(config, "flair",
#       "identify_gene_isoform_bin", "identify_gene_isoform")，与 flair_collapse.py /
#       flair_bam2bed12.py 同款；原聚合 flair.smk 的 docker/native 分支内联为 conda 或
#       PATH 直跑，现由 exec_mode 三模式显式分派）。
#
# 独立运行示例：
#   snakemake -s modules/flair/snakemake/flair_annotate.smk \
#       --config flair_annotate_input_bed12=out/aln.bed12 \
#               flair_annotate_gtf=gencode.v49.annotation.gtf \
#               flair_annotate_output=out/aln.annotated.bed \
#       --cores 4 --use-conda
# 流程内使用（bam2bed12 -> annotate -> collapse 三段链，见 flair_collapse.smk 头注）：
#   include: "modules/flair/snakemake/flair_annotate.smk"
#   rule all:
#       input: config["flair_annotate_output"]
#
# config 契约（均有默认；独立运行时用 --config 覆盖顶层键，flair.* 需在 Snakefile 的
# config/config.yaml 预设，与 td2 式规范一致）：
#   exec_mode                          : conda(默认) | docker | native
#   flair.docker_image                 : exec_mode=docker 时必填（镜像名，需含 identify_gene_isoform）
#   flair.identify_gene_isoform_bin    : exec_mode=native 时的 identify_gene_isoform 路径
#                                        （默认 identify_gene_isoform，走 PATH）
#   flair_annotate_input_bed12 : 必填 输入 BED12（bam2bed12 产物）
#   flair_annotate_gtf         : 必填 参考注释 GTF
#   flair_annotate_output      : 输出带注释 BED（默认 <输入去扩展名>.annotated.bed）

import os

config.setdefault("exec_mode", "conda")
config.setdefault("flair_annotate_input_bed12", "")
config.setdefault("flair_annotate_gtf", "")
_flair = config.setdefault("flair", {})
_flair.setdefault("docker_image", "")
_flair.setdefault("identify_gene_isoform_bin", "identify_gene_isoform")
_bed12 = config["flair_annotate_input_bed12"]
_stem = os.path.splitext(_bed12)[0] if _bed12 else ""
config.setdefault("flair_annotate_output", _stem + ".annotated.bed" if _stem else "")

rule flair_annotate:
    """identify_gene_isoform：BED12 + GTF -> 带基因注释 BED（flair_collapse 的 -q 输入）。"""
    input:
        bed12=config["flair_annotate_input_bed12"],
        gtf=config["flair_annotate_gtf"]
    output:
        annotated_bed=config["flair_annotate_output"]
    conda: "flair.yaml"
    log:
        os.path.join(os.path.dirname(config["flair_annotate_output"]), "flair_annotate.log")
    message:
        "flair annotate: {input.bed12} + {input.gtf} -> {output.annotated_bed}"
    script:
        "flair_annotate.py"
