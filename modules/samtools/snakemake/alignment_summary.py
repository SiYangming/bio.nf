"""Snakemake wrapper for samtools flagstat 汇总（与同目录 alignment_summary.smk 契约一致）。

契约：
  - input：多个 samtools flagstat 文本（config alignment_summary_flagstats，流程内赋值的列表）
  - output[0]：汇总 TSV（config alignment_summary_out；列 Sample / Total / Mapped / Rate）
  - log[0]：解析明细（逐文件记录 total / mapped / rate）
"""

__author__ = "Yangming Si"
__copyright__ = "Copyright 2026, Yangming Si"
__email__ = "siyangming1991@163.com"
__license__ = "MIT"

import os

snakemake = globals().get("snakemake")
if snakemake is None:
    raise SystemExit(0)

summary_path = snakemake.output[0]
log_path = snakemake.log[0]

with open(log_path, "w") as lg, open(summary_path, "w") as out:
    out.write(f"{'Sample':<15} {'Total':<12} {'Mapped':<12} {'Rate':<8}\n")
    out.write(f"{'-'*15} {'-'*8:<12} {'-'*8:<12} {'-'*6:<8}\n")
    for flagstat_file in snakemake.input:
        sample = os.path.basename(flagstat_file).replace(".flagstat.txt", "")
        total = "0"
        mapped = "0"
        rate = "N/A"
        with open(flagstat_file) as f:
            for line in f:
                if "in total" in line:
                    total = line.split()[0]
                if "mapped (" in line:
                    parts = line.split()
                    mapped = parts[0]
                    if len(parts) > 4:
                        rate = parts[4].replace("(", "").replace(")", "").replace("%", "") + "%"
        lg.write(f"Parsed {flagstat_file} -> total={total}, mapped={mapped}, rate={rate}\n")
        out.write(f"{sample:<15} {total:<12} {mapped:<12} {rate:<8}\n")
