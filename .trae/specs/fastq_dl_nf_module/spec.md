# fastq-dl Nextflow模块 - 产品需求文档

## Overview
- **Summary**: 构建一个符合nf-core标准格式的fastq-dl Nextflow模块，用于从ENA或SRA数据库下载FASTQ测序数据文件。模块接受accession号（Run/Experiment/Sample/Study级别）作为输入，输出下载的FASTQ.gz文件及相关元数据表。
- **Purpose**: 为bio.nf项目提供标准化的SRA/ENA数据下载模块，支持多种accession类型输入，与现有nf-core模块格式保持一致，便于在各种测序分析流程中复用。
- **Target Users**: 生物信息学研究人员、流程开发人员，需要从公共数据库下载测序数据并整合到Nextflow分析流程中。

## Goals
- 构建符合nf-core标准的fastq-dl模块（main.nf, meta.yml, environment.yml, tests/）
- 支持输入单个accession号（SRR/ERR/DRR/SRX/ERX/DRX等），下载对应的FASTQ文件
- 输出FASTQ.gz文件、run-info.tsv、run-mergers.tsv和versions.yml
- 支持conda和docker两种运行环境
- 支持task.ext.args自定义参数传递
- 支持task.ext.prefix自定义输出前缀
- 支持stub测试模式
- 提供完整的nf-test测试用例
- 使用单独的sra_ids_test.csv测试数据文件
- Docker测试配置--platform linux/amd64

## Non-Goals (Out of Scope)
- 不实现批量accession列表的处理逻辑（由流程层控制）
- 不实现复杂的样本合并逻辑（--group-by-experiment等高级功能由args参数控制）
- 不构建fastq-dl软件本身，仅封装现有工具
- 不提供GUI界面，仅提供Nextflow流程模块

## Background & Context
- bio.nf项目已维护多个nf-core格式的模块（cresil, ecc_finder, flair, kingfisher, minimap2, samtools等）
- 现有的kingfisher模块是类似的测序数据下载工具，可作为结构参考
- fastq-dl v4.0.1已在bioconda和biocontainers发布
- 测试数据从fetchngs.nf/testdata复制，在modules/fastqdl/下创建sra_ids_test.csv文件
- fastq-dl输出文件包括：*.fastq.gz（测序数据）、*-run-info.tsv（运行元数据）、*-run-mergers.tsv（合并信息）
- Docker测试需要配置--platform linux/amd64以兼容Apple Silicon

## Functional Requirements
- **FR-1**: 模块接受Groovy Map meta和accession字符串作为输入
- **FR-2**: 模块调用fastq-dl命令下载FASTQ数据
- **FR-3**: 输出下载的FASTQ.gz文件通道
- **FR-4**: 输出版本信息文件（versions.yml）
- **FR-5**: 输出run-info.tsv元数据表
- **FR-6**: 输出run-mergers.tsv合并信息表
- **FR-7**: 支持通过task.ext.args传递fastq-dl额外参数
- **FR-8**: 支持通过task.ext.prefix自定义输出文件名前缀
- **FR-9**: 支持stub运行模式，生成模拟输出文件
- **FR-10**: 同时支持conda环境和Docker容器运行

## Non-Functional Requirements
- **NFR-1**: 模块命名规范遵循nf-core标准，process名为FASTQDL_DOWNLOAD
- **NFR-2**: 模块目录结构与现有nf-core模块保持一致（modules/fastqdl/download/）
- **NFR-3**: meta.yml文档完整描述输入输出参数
- **NFR-4**: 测试用例覆盖正常运行和stub模式
- **NFR-5**: Docker镜像使用quay.io/biocontainers/fastq-dl:4.0.1--pyhdfd78af_0
- **NFR-6**: conda环境使用bioconda::fastq-dl=4.0.1

## Constraints
- **Technical**: 必须使用Nextflow DSL2语法，遵循nf-core模块规范
- **Business**: 模块需与bio.nf项目中现有模块风格一致
- **Dependencies**:
  - fastq-dl v4.0.1 (bioconda::fastq-dl=4.0.1)
  - Docker镜像: quay.io/biocontainers/fastq-dl:4.0.1--pyhdfd78af_0
  - 网络连接（用于从ENA/SRA下载数据）

## Assumptions
- 用户提供的accession号格式正确且存在于公共数据库中
- 运行环境有网络访问权限，可连接ENA/SRA服务器
- stub模式下测试不需要真实下载数据
- modules/fastqdl/sra_ids_test.csv包含有效的accession号（从fetchngs.nf/testdata复制）
- fastq-dl的--outdir参数设为当前工作目录，输出文件名由accession决定
- Docker测试需使用--platform linux/amd64以确保在Apple Silicon Mac上正常运行

## Acceptance Criteria

### AC-1: 模块文件结构完整
- **Given**: 模块目录modules/fastqdl/download/已创建
- **When**: 检查目录内容
- **Then**: 目录下包含main.nf, meta.yml, environment.yml, tests/main.nf.test, tests/nextflow.config文件
- **Verification**: `programmatic`
- **Notes**: 与现有模块（如kingfisher/get）结构一致

### AC-2: process命名和标签正确
- **Given**: main.nf文件已创建
- **When**: 检查process定义
- **Then**: process名为FASTQDL_DOWNLOAD，tag为$meta.id，label为process_medium
- **Verification**: `programmatic`

### AC-3: conda和docker环境配置正确
- **Given**: main.nf和environment.yml已创建
- **When**: 检查环境配置
- **Then**: conda使用environment.yml文件，docker使用quay.io/biocontainers/fastq-dl:4.0.1--pyhdfd78af_0，singularity使用galaxy镜像
- **Verification**: `programmatic`

### AC-4: 输入通道定义正确
- **Given**: main.nf文件已创建
- **When**: 检查input块
- **Then**: 接受tuple val(meta), val(accession)作为输入
- **Verification**: `programmatic`

### AC-5: 输出通道定义正确
- **Given**: main.nf文件已创建
- **When**: 检查output块
- **Then**: 输出fastq通道（*.fastq.gz）、versions通道（versions.yml）、run_info通道（*-run-info.tsv）、run_mergers通道（*-run-mergers.tsv）
- **Verification**: `programmatic`

### AC-6: 支持task.ext.args和task.ext.prefix
- **Given**: main.nf文件已创建
- **When**: 检查script块
- **Then**: 使用task.ext.args传递额外参数，使用task.ext.prefix定义输出前缀（默认使用meta.id）
- **Verification**: `programmatic`

### AC-7: stub模式正常工作
- **Given**: main.nf文件已创建
- **When**: 使用-stub参数运行
- **Then**: 生成模拟的FASTQ.gz文件、run-info.tsv、run-mergers.tsv和versions.yml，不执行真实下载
- **Verification**: `programmatic`

### AC-8: meta.yml文档完整
- **Given**: meta.yml文件已创建
- **When**: 检查内容
- **Then**: 包含name, description, keywords, tools, input, output, authors等完整字段
- **Verification**: `human-judgment`

### AC-9: nf-test测试用例完整
- **Given**: tests/main.nf.test已创建
- **When**: 检查测试用例
- **Then**: 至少包含正常模式和stub模式两个测试用例，使用模块目录下的sra_ids_test.csv测试数据文件
- **Verification**: `programmatic`

### AC-10: stub模式测试通过
- **Given**: 模块和测试用例已创建
- **When**: 运行nf-test stub模式测试
- **Then**: 测试成功通过，snapshot匹配
- **Verification**: `programmatic`

### AC-11: Docker测试配置正确
- **Given**: tests/nextflow.config已创建
- **When**: 检查Docker配置
- **Then**: 配置docker.enabled=true和runOptions='--platform linux/amd64'
- **Verification**: `programmatic`

### AC-12: 测试数据文件存在
- **Given**: 模块目录已创建
- **When**: 检查测试数据
- **Then**: modules/fastqdl/sra_ids_test.csv文件存在，包含有效的accession号
- **Verification**: `programmatic`

## Open Questions
- 无（已全部确认）
