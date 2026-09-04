#!/usr/bin/env python3
"""生成 td2 snakemake 集成测试用合成输入（明文 FASTA 占位）。

td2_longorfs/predict 规则做 dry-run / 静态回归时只需一个合法明文 FASTA，
本脚本生成最小占位（两转录本），内容无需真实生物学意义。
"""
from __future__ import annotations

import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 2:
        print(f"用法: {sys.argv[0]} <outdir>", file=sys.stderr)
        return 2
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)

    (out / "transcripts.fa").write_text(
        ">t1 test transcript 1\n"
        "ATGGCGACCCGTCGTGATATTTACGTCCGTAAATGA\n"
        ">t2 test transcript 2\n"
        "ATGAAACCCTTTGGGGCCCAGGTAGCTTAGGAATGA\n",
        encoding="utf-8",
    )
    print(f"已生成 td2 snakemake 测试占位数据 -> {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
