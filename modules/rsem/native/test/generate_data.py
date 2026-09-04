#!/usr/bin/env python3
"""生成 RSEM native 测试用的合成数据。

产出（<outdir> 下）：
  refs.fa     微型基因组（chr1: 300 bp，1..100 = t1 区、201..300 = t2 区）
  genes.gtf   两个基因/转录本（t1/chr1:1-100、t2/chr1:201-300，正义链）
  reads.fq    单端 reads（从 t1 转录本截取的 30 bp 片段，保证可唯一比对）
"""
from __future__ import annotations

import sys
from pathlib import Path

BLOCK_A = "ACGT" * 25        # 100 bp，t1 区（1..100）
BLOCK_B = "GGCCAATT" * 12 + "GGCC"  # 100 bp，t2 区（201..300）

READ_STARTS = (0, 35, 70, 5)  # chr1(即 t1 上) 4 个 30 bp read 起点


def write_fasta(path: Path) -> None:
    seq = BLOCK_A + "N" * 100 + BLOCK_B  # chr1: 300 bp（中部 100 bp 为基因间区）
    with open(path, "w") as fh:
        fh.write(">chr1\n")
        for i in range(0, len(seq), 60):
            fh.write(seq[i:i + 60] + "\n")


def write_gtf(path: Path) -> None:
    rows = [
        # seqname source feature start end score strand frame attributes
        ("chr1", "test", "transcript", "1", "100", ".", "+", ".",
         'gene_id "g1"; transcript_id "t1";'),
        ("chr1", "test", "exon", "1", "100", ".", "+", ".",
         'gene_id "g1"; transcript_id "t1";'),
        ("chr1", "test", "transcript", "201", "300", ".", "+", ".",
         'gene_id "g2"; transcript_id "t2";'),
        ("chr1", "test", "exon", "201", "300", ".", "+", ".",
         'gene_id "g2"; transcript_id "t2";'),
    ]
    with open(path, "w") as fh:
        for row in rows:
            fh.write("\t".join(row) + "\n")


def write_fastq(path: Path) -> None:
    seq = BLOCK_A
    with open(path, "w") as fh:
        for i, start in enumerate(READ_STARTS, start=1):
            read = seq[start:start + 30]
            fh.write(f"@read{i}\n{read}\n+\n{'I' * len(read)}\n")


def main() -> int:
    if len(sys.argv) != 2:
        print(f"用法: {sys.argv[0]} <outdir>", file=sys.stderr)
        return 2
    outdir = Path(sys.argv[1])
    outdir.mkdir(parents=True, exist_ok=True)
    write_fasta(outdir / "refs.fa")
    write_gtf(outdir / "genes.gtf")
    write_fastq(outdir / "reads.fq")
    print(f"已生成测试数据 -> {outdir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
