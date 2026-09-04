#!/usr/bin/env bash
set -euo pipefail

# Stage 02 · 引物去除/条形码拆分（lima，对应 02LIMA）

# ---- 路径自锚定：以脚本位置解析仓库根与包装器（保证任意机器/工作目录可运行）----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
LIMA_ANALYSIS=${LIMA_ANALYSIS:-"${REPO_ROOT}/modules/lima/native/lima_analysis.py"}   # lima 包装器（可环境变量覆盖）

# 可选：激活运行环境
# conda activate pacbio_iso_seq

# 配置参数（可通过环境变量覆盖）
DATA_DIR=${DATA_DIR:-""}                # 必填：指向包含样本子目录/CCS 结果的路径
OUT_BASE=${OUT_BASE:-"lima_output"}     # 输出根目录（默认当前目录下 lima_output）
CPUS_PER_TASK=${CPUS_PER_TASK:-8}       # 每个 lima 任务使用的线程数
PARA_CPU=${PARA_CPU:-28}                # 并发任务数（近似总并发 = PARA_CPU * CPUS_PER_TASK）
CMD_FILE=${CMD_FILE:-"${OUT_BASE}/lima_commands.txt"}
PRIMERS=${PRIMERS:-""}                  # 必填：引物 fasta 文件
LIMA_BIN=${LIMA_BIN:-""}                # 可选：lima 可执行文件路径（留空则从 PATH 解析）

if [[ -z "$DATA_DIR" || ! -d "$DATA_DIR" ]]; then
  echo "[ERROR] 未设置或不存在 DATA_DIR。请导出：export DATA_DIR=/path/to/ccs_output" >&2
  exit 1
fi
if [[ -z "$PRIMERS" || ! -f "$PRIMERS" ]]; then
  echo "[ERROR] 未设置或不存在 PRIMERS。请导出引物 fasta：export PRIMERS=/path/to/primers.fasta" >&2
  exit 1
fi

mkdir -p "$OUT_BASE"
> "$CMD_FILE"

echo "生成Lima命令列表到: $CMD_FILE"

# 搜索支持的输入后缀
while IFS= read -r reads; do
  sample_dir=$(basename "$(dirname "$reads")")
  outdir="$OUT_BASE/$sample_dir"
  mkdir -p "$outdir"
  cmd_line="python3 \"${LIMA_ANALYSIS}\" --reads \"$reads\" --primers \"$PRIMERS\" --outdir \"$outdir\" --cpus \"$CPUS_PER_TASK\""
  if [[ -n "$LIMA_BIN" ]]; then
    cmd_line+=" --lima-bin \"$LIMA_BIN\""
  fi
  echo "$cmd_line" >> "$CMD_FILE"
done < <(find "$DATA_DIR" -type f \( -name "*.bam" -o -name "*.fasta" -o -name "*.fastq" -o -name "*.fasta.gz" -o -name "*.fastq.gz" \))

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

echo "全部任务提交完成，Lima分析完成"
