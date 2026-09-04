"""Snakemake wrapper for uLTRA index（单参考规则配套，与同目录 ultra_index.smk 契约一致）。

契约（与同目录 ultra_index.smk 一致）：
  - input.fasta：参考基因组 FASTA（config ultra_index_fasta；.gz 时自动解压到索引目录）
  - input.gtf：已排序明文注释 GTF（config ultra_gtf；不支持 .gz——先 gunzip + sort）
  - output.done：touch marker（<ultra_index_dir>/done；*.pickle / *.db 由 uLTRA 写出）
  - params.index_dir / params.args：索引目录与透传参数（config ultra_index_dir / ultra.index_args）
  - 环境：exec_mode conda(默认)/docker/native；native 用 ultra.ultra_bin，
    docker 用镜像内默认名，conda 走 PATH（ultra.yaml 提供 uLTRA + minimap2/namfinder）
"""

from __future__ import annotations

import os
import sys

from snakemake.shell import shell

# 注入 bioskills 共享库目录（modules/），以导入共享 docker_wrapper
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
import docker_wrapper  # noqa: E402

log = snakemake.log_fmt_shell(stdout=True, stderr=True)
extra = str(snakemake.params["args"])
index_dir = os.path.abspath(str(snakemake.params["index_dir"]))
fasta = os.path.abspath(str(snakemake.input.fasta))
gtf = os.path.abspath(str(snakemake.input.gtf))

# 输入校验（快速失败，提示清晰）
if not os.path.isfile(fasta):
    raise FileNotFoundError(f"参考 FASTA 不存在: {fasta}")
if not os.path.isfile(gtf):
    raise FileNotFoundError(f"注释 GTF 不存在: {gtf}（uLTRA index 需要已排序明文 GTF）")
if gtf.endswith(".gz"):
    raise ValueError(
        "ultra_index: 输入 GTF 不支持 .gz——请先 gunzip + sort（见同目录 ultra_sort_gtf.smk 或 modules/gunzip）"
    )

os.makedirs(index_dir, exist_ok=True)

# 参考 FASTA 为 .gz 时先解压到索引目录（uLTRA index 不读压缩 fasta）
fasta_for_index = fasta
if fasta.endswith(".gz"):
    base = os.path.basename(fasta)
    for suf in (".fa.gz", ".fasta.gz", ".fastq.gz"):
        if base.endswith(suf):
            dec_name = base[: -len(suf)]
            break
    else:
        dec_name = base[: -len(".gz")]
    dec_path = os.path.join(index_dir, dec_name)
    if not os.path.exists(dec_path):
        shell(f"gzip -cd {fasta} > {dec_path}")
    fasta_for_index = dec_path

# Docker/二进制解析：docker 用镜像内默认名；native 用 config 的 ultra.ultra_bin；conda 走 PATH
docker_prefix, ultra_bin = docker_wrapper.docker_wrapper_binary(
    snakemake.config,
    "ultra",
    "ultra_bin",
    "uLTRA",
)

# uLTRA index 在索引目录内执行（产物 ./ 下的 *.pickle / *.db，与 nf-core 行为一致）
cwd_old = os.getcwd()
os.chdir(index_dir)
try:
    shell(f"{docker_prefix}{ultra_bin} index {fasta_for_index} {gtf} ./ {extra}{log}")
finally:
    os.chdir(cwd_old)
