"""Snakemake wrapper for uLTRA align（单样本规则配套，与同目录 ultra_align.smk 契约一致）。

契约（与同目录 ultra_align.smk 一致）：
  - input.reads / input.genome：reads 与参考基因组（.gz 自动解压到输出目录）
  - input.index_done：ultra_index.smk 的完成 marker（<ultra_index_dir>/done）
  - output.bam：<ultra_align_dir>/<prefix>.bam
  - params.prefix / params.args / params.sort_args：输出前缀与透传（config ultra.* / samtools.*）
  - 环境：exec_mode conda(默认)/docker/native；docker 用镜像内默认名（须含 samtools），
    native 用 config ultra.ultra_bin + samtools.samtools_bin，conda 走 PATH（ultra.yaml 提供）
  - 执行：把索引 *.pickle / *.db 复制到输出目录，uLTRA align --index ./（与 nf-core/native
    行为一致）→ samtools sort → 清理中间 sam
"""

from __future__ import annotations

import glob
import os
import shutil
import sys

from snakemake.shell import shell

# 注入 bioskills 共享库目录（modules/），以导入共享 docker_wrapper
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
import docker_wrapper  # noqa: E402

log = snakemake.log_fmt_shell(stdout=True, stderr=True)
extra = str(snakemake.params["args"])
sort_extra = str(snakemake.params["sort_args"])
prefix = str(snakemake.params["prefix"])
threads = max(int(snakemake.threads), 1)

bam = os.path.abspath(str(snakemake.output.bam))
align_dir = os.path.dirname(bam)
reads = os.path.abspath(str(snakemake.input.reads))
genome = os.path.abspath(str(snakemake.input.genome))
index_dir = os.path.dirname(os.path.abspath(str(snakemake.input.index_done)))

os.makedirs(align_dir, exist_ok=True)

# 输入校验（快速失败，提示清晰）
for label, p in (("reads", reads), ("genome", genome)):
    if not os.path.isfile(p):
        raise FileNotFoundError(f"{label} 不存在: {p}")
if not os.path.isfile(os.path.join(index_dir, "done")):
    raise FileNotFoundError(f"uLTRA index 产物缺失: {index_dir}/done（请先运行 ultra_index.smk）")

# 将索引文件复制到输出目录（uLTRA align --index ./ 读取，与 nf-core / native 行为一致）
pickles = glob.glob(os.path.join(index_dir, "*.pickle"))
dbs = glob.glob(os.path.join(index_dir, "*.db"))
if not pickles or not dbs:
    raise RuntimeError(f"index_dir 中未找到 *.pickle 或 *.db: {index_dir}")
for f in pickles + dbs:
    dest = os.path.join(align_dir, os.path.basename(f))
    if not os.path.exists(dest):
        shutil.copy2(f, dest)


def _decompress(path: str, outdir: str) -> str:
    """把可能 .gz 的输入解压到 outdir（已存在同名明文则跳过），返回明文绝对路径。"""
    if not path.endswith(".gz"):
        return path
    base = os.path.basename(path)
    for suf in (".fa.gz", ".fasta.gz", ".fastq.gz"):
        if base.endswith(suf):
            out_name = base[: -len(suf)]
            break
    else:
        out_name = base[: -len(".gz")]
    out_path = os.path.join(outdir, out_name)
    if not os.path.exists(out_path):
        shell(f"gzip -cd {path} > {out_path}")
    return out_path


genome_plain = _decompress(genome, align_dir)
reads_plain = _decompress(reads, align_dir)

exec_mode = snakemake.config["exec_mode"]
if exec_mode != "docker":
    # 预检 minimap2 / namfinder（uLTRA align 运行时按 PATH 查找；docker 模式依赖镜像内容，跳过）
    for dep in ("minimap2", "namfinder"):
        if shutil.which(dep) is None:
            raise RuntimeError(
                f"未检测到 {dep}（uLTRA align 需要）。conda 模式请用 --use-conda 创建 "
                "snakemake/ultra.yaml 环境；native 模式请安装 ultra_bioinformatics 并确保 PATH 包含 "
                "minimap2 / namfinder（mamba install -c conda-forge -c bioconda ultra_bioinformatics=0.1 minimap2 namfinder samtools）。"
            )

# Docker/二进制解析：uLTRA 三模式
docker_prefix, ultra_bin = docker_wrapper.docker_wrapper_binary(
    snakemake.config,
    "ultra",
    "ultra_bin",
    "uLTRA",
)
# samtools：docker 用同一镜像内默认名；native 用 config samtools.samtools_bin；conda 走 PATH
if exec_mode == "docker":
    sam_prefix, sam_bin = docker_prefix, "samtools"
else:
    sam_prefix = ""
    sam_bin = snakemake.config.get("samtools", {}).get("samtools_bin", "samtools") or "samtools"

# uLTRA align 在输出目录内执行：--index ./ 读取复制过来的索引；随后 samtools sort 生成 BAM 并清理 sam
# （命令链包进 bash group，使 log 重定向覆盖全链输出）
cmd = (
    f"{docker_prefix}{ultra_bin} align {genome_plain} {reads_plain} ./ "
    f"--t {threads} --prefix {prefix} --index ./ {extra} && "
    f"{sam_prefix}{sam_bin} sort --threads {threads} -o {bam} {sort_extra} {prefix}.sam && "
    f"rm -f {prefix}.sam"
)
cwd_old = os.getcwd()
os.chdir(align_dir)
try:
    shell("{" + cmd + "; }" + log)
finally:
    os.chdir(cwd_old)
