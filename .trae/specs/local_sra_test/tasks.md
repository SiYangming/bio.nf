# SRA to FASTQ 本地测试 - 实现计划

## [x] Task 1: 创建本地测试目录结构
- **Priority**: high
- **Depends On**: None
- **Description**: 
  - 创建测试输入目录 `/Users/siyangming/test_sra/ERR6326076/`
  - 创建测试输出目录 `/Users/siyangming/test_eccDNA/`
  - 复制 ERR6326076.sra 到测试目录
- **Acceptance Criteria Addressed**: [AC-1]
- **Test Requirements**:
  - `programmatic` TR-1.1: 测试目录结构正确创建
  - `programmatic` TR-1.2: ERR6326076.sra 文件存在于测试目录

## [/] Task 2: 运行本地转换流程
- **Priority**: high
- **Depends On**: Task 1
- **Description**: 
  - 运行 `nextflow run modules/sratools/main.nf` 命令
  - 传递 `--sra_dir` 和 `--outdir` 参数
  - 确保流程成功完成
- **Acceptance Criteria Addressed**: [AC-1]
- **Test Requirements**:
  - `programmatic` TR-2.1: Nextflow 流程退出码为 0
  - `programmatic` TR-2.2: 流程日志中无错误信息

## [ ] Task 3: 验证输出文件
- **Priority**: high
- **Depends On**: Task 2
- **Description**: 
  - 检查输出目录 `/Users/siyangming/test_eccDNA/ERR6326076/`
  - 验证 `.fastq.gz` 文件存在且不为空
- **Acceptance Criteria Addressed**: [AC-2]
- **Test Requirements**:
  - `programmatic` TR-3.1: 输出目录存在
  - `programmatic` TR-3.2: `.fastq.gz` 文件存在
  - `programmatic` TR-3.3: 文件大小 > 0 bytes

## [ ] Task 4: 验证 FASTQ 文件格式
- **Priority**: medium
- **Depends On**: Task 3
- **Description**: 
  - 使用 `zcat` 查看 FASTQ 文件内容
  - 验证文件格式符合 FASTQ 规范
- **Acceptance Criteria Addressed**: [AC-3]
- **Test Requirements**:
  - `human-judgement` TR-4.1: 文件内容以 @ 开头（序列头）
  - `human-judgement` TR-4.2: 序列行后有 + 行
  - `human-judgement` TR-4.3: 质量值行长度与序列行一致
