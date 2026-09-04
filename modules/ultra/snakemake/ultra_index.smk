# ultra_index.smk —— uLTRA index 单规则（Snakemake，td2 式）
#
# 环境：同目录 ultra.yaml（conda 相对本文件目录解析；ultra_bioinformatics + samtools +
#       minimap2/namfinder——后两者为 ultra_bioinformatics 运行时依赖随包安装）；
#       wrapper：同目录 ultra_index.py。
# 设计：config 驱动、单参考通用流程，不依赖 workflow 的 SAMPLES / {species} 通配层级
#       （源 ultra.smk 的 prepare_genome/prepare_gtf 参考准备已内联进 wrapper：.gz 参考自动
#       解压；GTF 须为已排序明文，先由 ultra_sort_gtf.smk 或调用方准备）。
#
# 独立运行示例（GTF 先排序）：
#   snakemake -s modules/ultra/snakemake/ultra_sort_gtf.smk \
#       --config ultra_gtf=refs/genes.gtf ultra_gtf_sorted=refs/genes.sorted.gtf --cores 1
#   snakemake -s modules/ultra/snakemake/ultra_index.smk \
#       --config ultra_index_fasta=refs/genome.fa.gz ultra_gtf=refs/genes.sorted.gtf \
#       ultra_index_dir=results/ULTRA/INDEX --cores 8 --use-conda
# 流程内使用（配合 ultra_sort_gtf.smk / ultra_align.smk）：
#   include: "modules/ultra/snakemake/ultra_sort_gtf.smk"
#   include: "modules/ultra/snakemake/ultra_index.smk"
#   include: "modules/ultra/snakemake/ultra_align.smk"
#   rule all:
#       input: os.path.join(config["ultra_index_dir"], "done")
#
# config 契约（均有默认；独立运行时用 --config 覆盖）：
#   exec_mode            : conda(默认) | docker | native
#   ultra.docker_image   : exec_mode=docker 时必填（镜像名，须含 uLTRA + minimap2/namfinder）
#   ultra.ultra_bin      : exec_mode=native 时的 uLTRA 路径（默认 uLTRA，走 PATH）
#   ultra.index_args     : 透传 uLTRA index 附加参数（默认 --disable_infer）
#   ultra_index_fasta    : 必填 参考基因组 FASTA（支持 .fa/.fasta；.gz 时 wrapper 自动解压）
#   ultra_gtf            : 必填 注释 GTF（明文、已排序；.gz 请先 gunzip + sort）
#   ultra_index_dir      : 索引输出目录（默认 results/ULTRA/INDEX；产物 *.pickle / *.db + done）
#   threads              : 规则调度线程（默认 8；index CPU 密集）
#
# 产物：<ultra_index_dir>/*.pickle + *.db（uLTRA index 写出），done marker 表示规则完成。

import os

config.setdefault("exec_mode", "conda")
config.setdefault("ultra_index_fasta", "")
config.setdefault("ultra_gtf", "")
config.setdefault("ultra_index_dir", "results/ULTRA/INDEX")
config.setdefault("threads", 8)
_ultra = config.setdefault("ultra", {})
_ultra.setdefault("docker_image", "")
_ultra.setdefault("ultra_bin", "uLTRA")
_ultra.setdefault("index_args", "--disable_infer")

if not config["ultra_index_fasta"]:
    raise ValueError("ultra_index.smk: 需提供 config['ultra_index_fasta']（参考基因组 FASTA）")
if not config["ultra_gtf"]:
    raise ValueError("ultra_index.smk: 需提供 config['ultra_gtf']（已排序注释 GTF）")

_ultra_index_dir = config["ultra_index_dir"]

rule ultra_index:
    """uLTRA index：GTF 引导的参考索引（产物 <ultra_index_dir>/*.pickle + *.db）。"""
    input:
        fasta=config["ultra_index_fasta"],
        gtf=config["ultra_gtf"]
    output:
        done=touch(os.path.join(_ultra_index_dir, "done"))
    params:
        index_dir=_ultra_index_dir,
        args=_ultra["index_args"]
    conda: "ultra.yaml"
    log:
        os.path.join(os.path.dirname(_ultra_index_dir), "logs", "ultra_index.log")
    threads:
        config["threads"]
    message:
        "uLTRA index: {input.fasta} + {input.gtf} -> {params.index_dir}"
    script:
        "ultra_index.py"
