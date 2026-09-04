"""Snakemake wrapper for samtools sort（通用单任务规则配套，与同目录 samtools_sort.smk 契约一致）。

契约：
  - input[0]：BAM/SAM/CRAM（config samtools_sort_input）
  - output[0]：sorted BAM（config samtools_sort_output）
  - params.extra：透传 sort 附加参数（config samtools.sort_extra_params，如 "-n"）
  - params.mem_overhead_factor：留给 samtools 自身的开销比例（默认 0.1）
  - resources.mem_mb：总内存预算（默认 8192），按线程均摊为 -m
  - 环境：exec_mode conda(默认) / docker / native；docker 用镜像内 samtools，
    native 用 config samtools.samtools_bin，conda 走 PATH
"""

__author__ = "Yangming Si"
__copyright__ = "Copyright 2026, Yangming Si"
__email__ = "siyangming1991@163.com"
__license__ = "MIT"

import os
import sys
import tempfile
from pathlib import Path

from snakemake.shell import shell

# 注入 bioskills 共享库目录（modules/），以导入共享 docker_wrapper
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
import docker_wrapper  # noqa: E402


extra = snakemake.params.get("extra", "")
log = snakemake.log_fmt_shell(stdout=True, stderr=True)

# Docker/native/conda 分派（docker 走镜像内默认名；native 走 config 的 samtools_bin；conda 走 PATH）
docker_prefix, tool_bin = docker_wrapper.docker_wrapper_binary(
    snakemake.config,
    "samtools",
    "samtools_bin",
    "samtools",
)

# 内存：`-m` 为每线程内存上限；总预算取 resources.mem_mb（默认 8192）并均摊到各线程
mem_overhead_factor = snakemake.params.get("mem_overhead_factor", 0.1)
assert 0 <= mem_overhead_factor < 1, "mem_overhead_factor must be between 0 and 1"

mem_total_mb = int(snakemake.resources.get("mem_mb", 8192))
mem_per_thread_mb = int(mem_total_mb / snakemake.threads * (1.0 - mem_overhead_factor))

# 线程：samtools sort 的 -@ 为额外线程数（主线程 1 + threads-1）
threads = "" if snakemake.threads <= 1 else " -@ {} ".format(snakemake.threads - 1)

# 确保输出目录存在，并以它为临时目录基址（Docker 挂载后可访问）
out_file = snakemake.output[0]
out_dir = os.path.dirname(out_file)
if not os.path.exists(out_dir):
    os.makedirs(out_dir)

# 临时目录放输出目录内，保证 Docker 可访问
with tempfile.TemporaryDirectory(dir=out_dir) as tmpdir:
    tmp_prefix = Path(tmpdir) / "samtools_sort"

    shell(
        "{docker_prefix}{tool_bin} sort"
        " {threads}"
        " -m {mem_per_thread_mb}M"
        " {extra}"
        " -T {tmp_prefix}"
        " -o {snakemake.output[0]}"
        " {snakemake.input[0]}"
        " {log}"
    )
