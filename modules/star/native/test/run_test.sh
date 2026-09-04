#!/usr/bin/env bash
# star native 最小回归测试
# 前置：python3 必须在 PATH；若本机装有 STAR（conda activate star-native、apt 安装
# rna-star 或容器），则追加跑 index+align 最小链路，否则跳过（自省测试必跑）。
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NATIVE="$(dirname "$HERE")"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "==> [1/5] 生成测试数据（合成参考 + reads）"
python "$HERE/generate_data.py" "$WORK"
test -f "$WORK/refs.fa"
test -f "$WORK/reads_se.fq"

echo "==> [2/5] main.py --list-commands 自省"
python "$NATIVE/main.py" --list-commands | tee "$WORK/commands.txt"
grep -q "^index " "$WORK/commands.txt"
grep -q "^align " "$WORK/commands.txt"

echo "==> [3/5] main.py --schema 自省"
python "$NATIVE/main.py" --schema > "$WORK/schema.json"
test -s "$WORK/schema.json"
python -c "import json,sys; json.load(open('$WORK/schema.json')); print('schema JSON 合法')"

echo "==> [4/5] main.py index/align 最小链路（需要 STAR，未安装则跳过）"
if command -v STAR >/dev/null 2>&1; then
    # 小基因组必须调小 --genomeSAindexNbases，否则 STAR 报 FATAL
    python "$NATIVE/main.py" index "$WORK/refs.fa" "$WORK/genomeDir" \
        --genome-sa-index-nbases 5 --threads 2
    test -f "$WORK/genomeDir/Genome"
    test -f "$WORK/genomeDir/SA"
    test -f "$WORK/genomeDir/SAindex"

    python "$NATIVE/main.py" align --genome-dir "$WORK/genomeDir" -U "$WORK/reads_se.fq" \
        -o "$WORK/se.sam" --out-sam-type SAM --threads 2
    test -s "$WORK/se.sam"
    grep -q "@SQ" "$WORK/se.sam"
    # 单端 4 条 read 全部应被唯一比对（伪随机参考无重复 40-mer）
    ALIGNED=$(grep -c -v "^@" "$WORK/se.sam")
    test "$ALIGNED" -eq 4

    python "$NATIVE/main.py" align --genome-dir "$WORK/genomeDir" \
        -1 "$WORK/reads_1.fq" -2 "$WORK/reads_2.fq" -o "$WORK/pe.sam" \
        --out-sam-type SAM --threads 2
    test -s "$WORK/pe.sam"
    grep -q "@SQ" "$WORK/pe.sam"

    # 默认 BAM SortedByCoordinate 输出
    python "$NATIVE/main.py" align --genome-dir "$WORK/genomeDir" -U "$WORK/reads_se.fq" \
        -o "$WORK/se.bam" --threads 2
    test -s "$WORK/se.bam"
else
    echo "  [SKIP] 未检测到 STAR，跳过 index+align（仅跑自省链路）"
fi

echo "==> [5/5] 版本探测（可选信息）"
if command -v STAR >/dev/null 2>&1; then
    STAR --version | head -n 1
fi

echo "ALL TESTS PASSED"
