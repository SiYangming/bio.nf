#!/usr/bin/env bash
set -euo pipefail

# Stage 04 · BAM -> FASTA（bamtools convert，对应 04BAMTOOLS_CONVERT）

# ---- 路径自锚定：以脚本位置解析仓库根与包装器（保证任意机器/工作目录可运行）----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
BAMTOOLS_CONVERT=${BAMTOOLS_CONVERT:-"${REPO_ROOT}/modules/bamtools/native/bamtools_convert.py"}   # bamtools 包装器（可环境变量覆盖）

# 可选：激活运行环境
# conda activate pacbio_iso_seq

# 配置参数（可通过环境变量覆盖）
DATA_DIR=${DATA_DIR:-""}                        # 必填：指向包含样本子目录 / refine 结果的路径
OUT_BASE=${OUT_BASE:-"bamtools_convert_output"} # 输出根目录（默认当前目录下 bamtools_convert_output）
FORMAT=${FORMAT:-"fasta"}                       # 转换格式（bed/fasta/fastq/json/pileup/sam/yaml）
ARGS=${ARGS:-""}                                # 附加参数，例如 "-region chr1:100-200"
PARA_CPU=${PARA_CPU:-28}                        # 并发任务数
CMD_FILE=${CMD_FILE:-"${OUT_BASE}/bamtools_convert_commands.txt"}
BAMTOOLS_BIN=${BAMTOOLS_BIN:-""}                # 可选：bamtools 可执行文件路径（留空则从 PATH 解析）

if [[ -z "$DATA_DIR" || ! -d "$DATA_DIR" ]]; then
  echo "[ERROR] 未设置或不存在 DATA_DIR。请导出：export DATA_DIR=/path/to/isoseq3_refine_output" >&2
  exit 1
fi

mkdir -p "$OUT_BASE"
> "$CMD_FILE"

echo "生成 BamTools convert 命令列表到: $CMD_FILE"

while IFS= read -r bam; do
  sample_dir=$(basename "$(dirname "$bam")")
  outdir="$OUT_BASE/$sample_dir"
  mkdir -p "$outdir"
  cmd_line="python3 \"${BAMTOOLS_CONVERT}\" --bam \"$bam\" --outdir \"$outdir\" --format \"$FORMAT\""
  if [[ -n "$ARGS" ]]; then
    cmd_line+=" --args \"$ARGS\""
  fi
  if [[ -n "$BAMTOOLS_BIN" ]]; then
    cmd_line+=" --bamtools-bin \"$BAMTOOLS_BIN\""
  fi
  echo "$cmd_line" >> "$CMD_FILE"
done < <(find "$DATA_DIR" -type f -name "*.bam")

echo "命令数量: $(wc -l < "$CMD_FILE")"

# 优先使用 ParaFly，其次 GNU parallel，最后 xargs 作为降级方案
if command -v ParaFly >/dev/null 2>&1; then
  echo "使用 ParaFly 并发执行, CPU=$PARA_CPU"
  ParaFly -c "$CMD_FILE" -CPU "$PARA_CPU"
elif command -v parallel >/dev/null 2>&1; then
  echo "使用 GNU parallel 并发执行, -j=$PARA_CPU"
  parallel -j "$PARA_CPU" --delay 0.2 --bar < "$CMD_FILE"
else
  echo "使用 xargs 并发执行, -P=$PARA_CPU (如遇到复杂引号问题，建议安装 ParaFly 或 parallel)"
  xargs -I CMD -P "$PARA_CPU" bash -c 'CMD' < "$CMD_FILE"
fi

echo "全部任务提交完成，BamTools convert 完成"
