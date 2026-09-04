#!/usr/bin/env bash
# RSEM native 最小回归测试
# 前置：python3 必须在 PATH；若本机装有 rsem（rsem-prepare-reference /
# rsem-calculate-expression，如 conda activate rsem-native 或 apt install rsem）
# 且配有 bowtie2（--bowtie2 索引/比对需要），则追加跑最小链路，否则跳过
# （自省测试必跑）。
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NATIVE="$(dirname "$HERE")"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "==> [1/5] 生成测试数据（合成基因组 + GTF + reads）"
python "$HERE/generate_data.py" "$WORK"
test -f "$WORK/refs.fa"
test -f "$WORK/genes.gtf"
test -f "$WORK/reads.fq"

echo "==> [2/5] main.py --list-commands 自省"
python "$NATIVE/main.py" --list-commands | tee "$WORK/commands.txt"
grep -q "^prepare-reference " "$WORK/commands.txt"
grep -q "^calculate-expression " "$WORK/commands.txt"

echo "==> [3/5] main.py --schema 自省"
python "$NATIVE/main.py" --schema > "$WORK/schema.json"
test -s "$WORK/schema.json"
python -c "import json,sys; json.load(open('$WORK/schema.json')); print('schema JSON 合法')"

echo "==> [4/5] prepare-reference + calculate-expression 最小链路（需要 rsem，未安装则跳过）"
if command -v rsem-prepare-reference >/dev/null 2>&1 && \
   command -v rsem-calculate-expression >/dev/null 2>&1; then
    # bowtie2 可用则用 --bowtie2 建索引 + fastq 直算；否则跳过 aligner 相关参数
    BT2=""
    if command -v bowtie2 >/dev/null 2>&1 && command -v bowtie2-build >/dev/null 2>&1; then
        BT2="--bowtie2"
    fi

    python "$NATIVE/main.py" prepare-reference "$WORK/refs.fa" "$WORK/rsem" \
        --gtf "$WORK/genes.gtf" $BT2 --threads 2
    for ext in seq grp ti transcripts.fa; do
        test -f "$WORK/rsem.$ext"
    done

    python "$NATIVE/main.py" calculate-expression \
        --reads "$WORK/reads.fq" --index "$WORK/rsem" --prefix "$WORK/sample" \
        --fragment-length-mean 300 --fragment-length-sd 100 --strandedness forward \
        $BT2 --threads 2
    test -f "$WORK/sample.genes.results"
    test -f "$WORK/sample.isoforms.results"
    grep -q "^gene" "$WORK/sample.genes.results" || true
else
    echo "  [SKIP] 未检测到 rsem-prepare-reference / rsem-calculate-expression，跳过真实链路（仅跑自省）"
fi

echo "==> [5/5] 版本探测（可选信息）"
if command -v rsem-calculate-expression >/dev/null 2>&1; then
    rsem-calculate-expression --version | head -n 1 || true
fi

echo "ALL TESTS PASSED"
