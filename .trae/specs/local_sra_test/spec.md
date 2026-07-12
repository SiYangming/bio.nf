# SRA to FASTQ 本地测试 - 产品需求文档

## Overview
- **Summary**: 在本地环境测试 SRA 文件到 FASTQ 文件的转换流程，验证修复后的脚本能够正确处理单端和双端测序数据
- **Purpose**: 验证 `fasterqdump/main.nf` 中修复的单端/双端数据处理逻辑是否正确，确保流程在服务器上运行时不会出现类似错误
- **Target Users**: 开发人员，验证流程正确性

## Goals
- 验证 ERR6326076.sra 文件能够成功转换为 FASTQ
- 验证转换后的文件格式正确，可读
- 验证单端/双端数据处理逻辑修复有效

## Non-Goals (Out of Scope)
- 不测试大规模数据转换
- 不测试服务器环境
- 不测试 circdna.nf 主流程

## Background & Context
- 之前服务器上运行时，单端测序数据（如 SRR24335765）因脚本错误移动文件导致 `pigz` 找不到文件
- 已修复 `fasterqdump/main.nf` 第28行的逻辑：只有同时存在 `prefix.fastq` 和 `prefix_1.fastq` 时才移动第三个文件

## Functional Requirements
- **FR-1**: 使用 ERR6326076.sra 测试转换流程
- **FR-2**: 验证转换后的 FASTQ 文件存在且不为空
- **FR-3**: 验证 FASTQ 文件格式正确

## Non-Functional Requirements
- **NFR-1**: 测试在本地环境完成
- **NFR-2**: 使用 Docker 容器运行

## Constraints
- **Technical**: 需要 Docker 运行环境
- **Dependencies**: Nextflow、Docker

## Assumptions
- Docker 已安装并运行
- Nextflow 已安装
- ERR6326076.sra 文件存在

## Acceptance Criteria

### AC-1: SRA 文件成功转换
- **Given**: ERR6326076.sra 文件存在于测试目录
- **When**: 运行 `nextflow run modules/sratools/main.nf`
- **Then**: 流程成功完成，无错误
- **Verification**: `programmatic`

### AC-2: FASTQ 文件存在
- **Given**: 转换流程成功完成
- **When**: 检查输出目录
- **Then**: ERR6326076 目录下存在 `.fastq.gz` 文件
- **Verification**: `programmatic`

### AC-3: FASTQ 文件格式正确
- **Given**: FASTQ 文件存在
- **When**: 使用 `zcat` 查看文件内容
- **Then**: 文件内容符合 FASTQ 格式（@开头的序列头，序列，+，质量值）
- **Verification**: `human-judgment`

## Open Questions
- [ ] ERR6326076 是单端还是双端数据？
