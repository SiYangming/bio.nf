#!/usr/bin/env bash
# bowtie2 native 最小回归测试
# 前置：python3 必须在 PATH；若本机装有 bowtie2/bowtie2-build（conda activate bowtie2-native
# 或 apt 安装），则追加跑 build+align 最小链路，否则跳过（自省测试必跑）。
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
grep -q "^build " "$WORK/commands.txt"
grep -q "^align " "$WORK/commands.txt"

echo "==> [3/5] main.py --schema 自省"
python "$NATIVE/main.py" --schema > "$WORK/schema.json"
test -s "$WORK/schema.json"
python -c "import json,sys; json.load(open('$WORK/schema.json')); print('schema JSON 合法')"

echo "==> [4/5] main.py build/align 最小链路（需要 bowtie2，未安装则跳过）"
if command -v bowtie2 >/dev/null 2>&1 && command -v bowtie2-build >/dev/null 2>&1; then
    python "$NATIVE/main.py" build "$WORK/refs.fa" "$WORK/bt2idx" --threads 2
    test -f "$WORK/bt2idx.1.bt2"
    test -f "$WORK/bt2idx.2.bt2"
    test -f "$WORK/bt2idx.rev.2.bt2"

    python "$NATIVE/main.py" align -x "$WORK/bt2idx" -1 "$WORK/reads_1.fq" -2 "$WORK/reads_2.fq" \
        -o "$WORK/pe.sam" --threads 2
    test -f "$WORK/pe.sam"
    grep -q "@SQ" "$WORK/pe.sam"

    python "$NATIVE/main.py" align -x "$WORK/bt2idx" -U "$WORK/reads_se.fq" \
        -o "$WORK/se.sam" --threads 2
    test -f "$WORK/se.sam"
    # 单端 4 条 read 全部应被比对（chr1 片段唯一）
    ALIGNED=$(grep -c -v "^@" "$WORK/se.sam")
    test "$ALIGNED" -eq 4
else
    echo "  [SKIP] 未检测到 bowtie2 / bowtie2-build，跳过 build+align（仅跑自省链路）"
fi

echo "==> [5/5] 版本探测（可选信息）"
if command -v bowtie2 >/dev/null 2>&1; then
    bowtie2 --version | head -n 1
fi

echo "ALL TESTS PASSED"
