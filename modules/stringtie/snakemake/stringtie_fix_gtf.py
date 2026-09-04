"""Snakemake wrapper for stringtie fix_gtf（GTF 坐标修复 $4<=$5，纯文本）。

契约（与同目录 stringtie_fix_gtf.smk 一致）：
  - input.gtf            ：输入 GTF
  - output.fixed_gtf     ：修复后 GTF（注释行保留；$4>$5 交换）
  - 实现：以 Path(__file__).parent 定位同目录 helper fix_gtf.awk，
    调系统 awk（-F tab / -v OFS=tab）执行；纯文本处理无需 stringtie 二进制，
    不挂 conda（awk 走系统 PATH），亦不走 docker/native 三模式。
"""

from __future__ import annotations

from pathlib import Path

from snakemake.shell import shell

_awk = Path(__file__).resolve().parent / "fix_gtf.awk"
_log = snakemake.log_fmt_shell(stdout=False, stderr=True)

shell(
    f'awk -F "\\t" -v OFS="\\t" -f "{_awk}" '
    f'"{snakemake.input.gtf}" > "{snakemake.output.fixed_gtf}" {_log}'
)
