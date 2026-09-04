# ultra_align.smk —— uLTRA align 单规则（Snakemake，td2 式）
#
# 环境：同目录 ultra.yaml（conda 相对本文件目录解析；ultra_bioinformatics + samtools +
#       minimap2/namfinder）；wrapper：同目录 ultra_align.py。
# 设计：config 驱动、单样本通用流程；依赖 ultra_index.smk 产物（<ultra_index_dir>/done），
#       不依赖 workflow 的 SAMPLES / {sample} 通配层级。
#
# 独立运行示例（先建索引）：
#   snakemake -s modules/ultra/snakemake/ultra_index.smk \
#       --config ultra_index_fasta=refs/genome.fa ultra_gtf=refs/genes.sorted.gtf \
#       ultra_index_dir=results/ULTRA/INDEX --cores 8 --use-conda
#   snakemake -s modules/ultra/snakemake/ultra_align.smk \
#       --config ultra_genome=refs/genome.fa ultra_reads=reads/sample.fa \
#       ultra_index_dir=results/ULTRA/INDEX ultra_prefix=sample --cores 8 --use-conda
# 流程内使用（配合 ultra_sort_gtf.smk / ultra_index.smk）：
#   include: "modules/ultra/snakemake/ultra_sort_gtf.smk"
#   include: "modules/ultra/snakemake/ultra_index.smk"
#   include: "modules/ultra/snakemake/ultra_align.smk"
#   rule all:
#       input: os.path.join(config["ultra_align_dir"], config["ultra_prefix"] + ".bam")
#
# config 契约（均有默认；独立运行时用 --config 覆盖）：
#   exec_mode            : conda(默认) | docker | native
#   ultra.docker_image   : exec_mode=docker 时必填（镜像名，须含 uLTRA + samtools + minimap2/namfinder）
#   ultra.ultra_bin      : exec_mode=native 时的 uLTRA 路径（默认 uLTRA，走 PATH）
#   ultra.align_args     : 透传 uLTRA align 附加参数，如 "--isoseq"（默认空）
#   samtools.samtools_bin: exec_mode=native 时的 samtools 路径（默认 samtools，走 PATH）
#   samtools.sort_args   : 透传 samtools sort 附加参数（默认空）
#   ultra_genome         : 必填 参考基因组 FASTA（须与建索引一致；.gz 时 wrapper 自动解压）
#   ultra_reads          : 必填 输入 reads（fasta/fastq；.gz 时 wrapper 自动解压）
#   ultra_index_dir      : uLTRA index 输出目录（ultra_index.smk 产物，须含 done marker）
#   ultra_align_dir      : 输出目录（默认 results/ULTRA；bam 落于 <dir>/<prefix>.bam）
#   ultra_prefix         : 输出前缀（默认取 reads 文件名去扩展名）
#   threads              : 规则调度线程（默认 8；align 与 samtools sort 各用一份）
#
# 产物：<ultra_align_dir>/<prefix>.bam；中间 pickle/db 副本与解压 reads/genome 留在同目录。

import os

config.setdefault("exec_mode", "conda")
config.setdefault("ultra_genome", "")
config.setdefault("ultra_reads", "")
config.setdefault("ultra_index_dir", "results/ULTRA/INDEX")
config.setdefault("ultra_align_dir", "results/ULTRA")
config.setdefault("threads", 8)
_ultra = config.setdefault("ultra", {})
_ultra.setdefault("docker_image", "")
_ultra.setdefault("ultra_bin", "uLTRA")
_ultra.setdefault("align_args", "")
_samtools = config.setdefault("samtools", {})
_samtools.setdefault("samtools_bin", "samtools")
_samtools.setdefault("sort_args", "")

if not config["ultra_genome"]:
    raise ValueError("ultra_align.smk: 需提供 config['ultra_genome']（参考基因组 FASTA）")
if not config["ultra_reads"]:
    raise ValueError("ultra_align.smk: 需提供 config['ultra_reads']（reads fasta/fastq）")

# 默认前缀 = reads 文件名去扩展名（与 native main.py 的推断一致）
_reads_base = os.path.basename(config["ultra_reads"])
_auto_prefix = ""
for _suf in (".fa.gz", ".fasta.gz", ".fastq.gz", ".fa", ".fasta", ".fastq"):
    if _reads_base.endswith(_suf):
        _auto_prefix = _reads_base[: -len(_suf)]
        break
if not _auto_prefix:
    _auto_prefix = os.path.splitext(_reads_base)[0]
config.setdefault("ultra_prefix", _auto_prefix)

rule ultra_align:
    """uLTRA align + samtools sort：reads -> BAM（产物 <ultra_align_dir>/<prefix>.bam）。"""
    input:
        reads=config["ultra_reads"],
        genome=config["ultra_genome"],
        index_done=os.path.join(config["ultra_index_dir"], "done")
    output:
        bam=os.path.join(config["ultra_align_dir"], config["ultra_prefix"] + ".bam")
    params:
        align_dir=config["ultra_align_dir"],
        prefix=config["ultra_prefix"],
        args=_ultra["align_args"],
        sort_args=_samtools["sort_args"]
    conda: "ultra.yaml"
    log:
        os.path.join(os.path.dirname(config["ultra_align_dir"]), "logs", "ultra_align.log")
    threads:
        config["threads"]
    message:
        "uLTRA align: {input.reads} -> {output.bam}"
    script:
        "ultra_align.py"
