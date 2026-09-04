#!/usr/bin/env python3
"""生成 umi_tools native 测试用的合成数据。

产出（均动态生成，保持仓库轻量）：
  <outdir>/reads.fastq       供 extract：read 序列 5' 端带 6 bp UMI + 20 bp insert
  <outdir>/reads.sam         供 dedup：6 条 mapped reads，read name 形如
                             {sample}_{UMI}（umi_tools extract 输出风格，"_" 分隔），
                             4 个 UMI 组（其中 2 组各含 2 条重复）→ dedup 后应剩 4 条
"""
from __future__ import annotations

import random
import sys
from pathlib import Path

UMI_LEN = 6
INSERT_LEN = 20
QUAL = "I" * (UMI_LEN + INSERT_LEN)

# extract 用 reads：read1/read2 共享 UMI（AAAAAA），read3/read4 各自唯一
EXTRACT_READS = [
    ("read1", "AAAAAA", "ACGTACGTACGTACGTACGTT"),
    ("read2", "AAAAAA", "ACGTACGTACGTACGTACGTG"),
    ("read3", "CCCCCC", "TTTTGGGGCCCCAAAATTTTGG"),
    ("read4", "TTTTTT", "GGGGCCCCAAAATTTTGGGGCC"),
]

# dedup 用 mapped reads：6 条 -> 4 个 UMI 组（2 组各 2 条重复 + 2 组唯一）
DEDUP_READS = [
    # (name, umi, pos)  —— flag=0, chr1, MAPQ=255, cigar=10M, seq=10bp
    ("s1", "AAAAAA", 100),
    ("s2", "AAAAAA", 100),   # 与 s1 重复（同 UMI 同位置）
    ("s3", "CCCCCC", 200),
    ("s4", "CCCCCC", 200),   # 与 s3 重复
    ("s5", "GGGGGG", 300),
    ("s6", "TTTTTT", 400),
]


def write_fastq(path: Path) -> None:
    with open(path, "w") as fh:
        for name, umi, insert in EXTRACT_READS:
            fh.write(f"@{name}\n")
            fh.write(umi + insert + "\n")
            fh.write("+\n")
            fh.write(QUAL + "\n")


def write_sam(path: Path) -> None:
    lines = ["@HD\tVN:1.6\tSO:unsorted", "@SQ\tSN:chr1\tLN:1000"]
    for name, umi, pos in DEDUP_READS:
        rname = f"{name}_{umi}"
        seq = "ACGTACGTAC"  # 10M 与 10 bp 匹配
        lines.append(
            f"{rname}\t0\tchr1\t{pos}\t255\t10M\t*\t0\t0\t{seq}\tFFFFFFFFFF"
        )
    with open(path, "w") as fh:
        fh.write("\n".join(lines) + "\n")


def main() -> int:
    if len(sys.argv) != 2:
        print(f"用法: {sys.argv[0]} <outdir>", file=sys.stderr)
        return 2
    outdir = Path(sys.argv[1])
    outdir.mkdir(parents=True, exist_ok=True)
    write_fastq(outdir / "reads.fastq")
    write_sam(outdir / "reads.sam")
    print(f"已生成测试数据 -> {outdir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
