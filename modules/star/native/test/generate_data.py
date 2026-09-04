#!/usr/bin/env python3
"""生成 star native 测试用的合成数据。

产出（<outdir> 下）：
  refs.fa      微型参考序列（chr1/chr2/chr3 各 1000 bp，确定性伪随机，避免重复 k-mer）
  reads_se.fq  单端 reads（chr1 上的 4 条 40 bp 片段，保证唯一比对）
  reads_1.fq / reads_2.fq  双端 reads（chr1 上的 2 对 40 bp 片段）
"""
from __future__ import annotations

import random
import sys
from pathlib import Path

CONTIGS = {"chr1": 1000, "chr2": 1000, "chr3": 1000}

SE_STARTS = (100, 300, 500, 700)        # chr1 上 4 个单端 read 起点
PE_STARTS = (150, 600)                  # chr1 上双端 read 起点
READ_LEN = 40


def gen_seq(length: int, seed: int) -> str:
    """确定性伪随机序列，避免纯周期序列导致 reads 多比对。"""
    rng = random.Random(seed)
    return "".join(rng.choice("ACGT") for _ in range(length))


def write_fasta(path: Path) -> None:
    with open(path, "w") as fh:
        for i, (name, length) in enumerate(CONTIGS.items()):
            seq = gen_seq(length, seed=42 + i)
            fh.write(f">{name}\n")
            for j in range(0, len(seq), 60):
                fh.write(seq[j:j + 60] + "\n")


def write_fastq(path: Path, reads: list[str]) -> None:
    with open(path, "w") as fh:
        for i, seq in enumerate(reads, start=1):
            fh.write(f"@read{i}\n{seq}\n+\n{'I' * len(seq)}\n")


def main() -> int:
    if len(sys.argv) != 2:
        print(f"用法: {sys.argv[0]} <outdir>", file=sys.stderr)
        return 2
    outdir = Path(sys.argv[1])
    outdir.mkdir(parents=True, exist_ok=True)

    chr1 = gen_seq(CONTIGS["chr1"], seed=42)
    write_fasta(outdir / "refs.fa")
    write_fastq(outdir / "reads_se.fq", [chr1[s:s + READ_LEN] for s in SE_STARTS])
    write_fastq(outdir / "reads_1.fq", [chr1[s:s + READ_LEN] for s in PE_STARTS])
    write_fastq(outdir / "reads_2.fq", [chr1[s + 60:s + 60 + READ_LEN] for s in PE_STARTS])
    print(f"已生成测试数据 -> {outdir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
