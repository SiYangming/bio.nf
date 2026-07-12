# fastq-dl Nextflow模块 - 实现计划（分解并排序的任务列表）

## [x] Task 1: 创建模块目录结构、environment.yml和测试数据文件
- **Priority**: high
- **Depends On**: None
- **Description**: 
  - 创建modules/fastqdl/download/目录结构
  - 创建modules/fastqdl/download/tests/目录
  - 创建environment.yml文件，配置bioconda::fastq-dl=4.0.1
  - 从fetchngs.nf/testdata复制sra_ids_test.csv到modules/fastqdl/
- **Acceptance Criteria Addressed**: AC-1, AC-3, AC-12
- **Test Requirements**:
  - `programmatic` TR-1.1: 目录modules/fastqdl/download/存在且包含environment.yml和tests/子目录
  - `programmatic` TR-1.2: environment.yml包含name: fastq-dl和bioconda::fastq-dl=4.0.1依赖
  - `programmatic` TR-1.3: modules/fastqdl/sra_ids_test.csv文件存在且包含accession号
- **Notes**: 参照kingfisher模块的目录结构，测试数据文件直接放modules/fastqdl/下

## [x] Task 2: 创建main.nf模块主文件
- **Priority**: high
- **Depends On**: Task 1
- **Description**: 
  - 定义FASTQDL_DOWNLOAD process
  - 配置input: tuple val(meta), val(accession)
  - 配置output: fastq通道(*.fastq.gz), versions通道(versions.yml), run_info通道(*-run-info.tsv), run_mergers通道(*-run-mergers.tsv)
  - 配置conda和docker/singularity环境
  - 实现script块，调用fastq-dl --accession命令
  - 实现stub块，生成模拟输出文件（包括run-mergers.tsv）
  - 支持task.ext.args和task.ext.prefix
- **Acceptance Criteria Addressed**: AC-2, AC-3, AC-4, AC-5, AC-6, AC-7
- **Test Requirements**:
  - `programmatic` TR-2.1: process名为FASTQDL_DOWNLOAD
  - `programmatic` TR-2.2: 输入为tuple val(meta), val(accession)
  - `programmatic` TR-2.3: 输出包含fastq、versions、run_info、run_mergers四个通道
  - `programmatic` TR-2.4: conda和docker镜像配置正确
  - `programmatic` TR-2.5: script块使用fastq-dl命令，支持$args
  - `programmatic` TR-2.6: stub块创建模拟FASTQ.gz、run-info.tsv、run-mergers.tsv和versions.yml
  - `human-judgement` TR-2.7: 代码风格与现有nf-core模块一致
- **Notes**: 参照kingfisher/get/main.nf的写法，注意输出文件的命名和收集方式

## [x] Task 3: 创建meta.yml模块文档
- **Priority**: high
- **Depends On**: Task 2
- **Description**: 
  - 编写meta.yml文件，包含完整的模块文档
  - 描述工具信息（name, description, homepage, licence等）
  - 详细描述input和output参数（包括run_mergers）
  - 添加authors和maintainers
- **Acceptance Criteria Addressed**: AC-8
- **Test Requirements**:
  - `human-judgement` TR-3.1: meta.yml包含所有必需字段（name, description, keywords, tools, input, output, authors）
  - `human-judgement` TR-3.2: input和output描述准确，与main.nf一致（包含run_mergers）
  - `human-judgement` TR-3.3: tools部分包含fastq-dl的主页、文档和许可证信息
- **Notes**: 参照kingfisher/get/meta.yml的格式

## [x] Task 4: 创建测试配置文件和测试用例
- **Priority**: high
- **Depends On**: Task 2, Task 3
- **Description**: 
  - 创建tests/nextflow.config，配置docker.enabled=true和runOptions='--platform linux/amd64'
  - 创建tests/main.nf.test，包含nf-test测试用例
  - 测试用例1: stub模式运行（使用modules/fastqdl/sra_ids_test.csv中的accession）
  - 测试用例2: 正常模式（可选，需要网络）
- **Acceptance Criteria Addressed**: AC-9, AC-11
- **Test Requirements**:
  - `programmatic` TR-4.1: tests/nextflow.config存在，配置了docker.enabled=true和--platform linux/amd64
  - `programmatic` TR-4.2: tests/main.nf.test存在，包含至少2个测试用例
  - `programmatic` TR-4.3: 测试使用modules/fastqdl/sra_ids_test.csv数据
  - `programmatic` TR-4.4: stub模式测试用例可以成功运行
- **Notes**: 参照kingfisher/get/tests/的写法，使用SRR号作为测试输入

## [x] Task 5: 运行stub模式测试并生成snapshot
- **Priority**: high
- **Depends On**: Task 4
- **Description**: 
  - 运行nf-test stub模式测试
  - 验证输出文件是否符合预期（包括run-mergers.tsv）
  - 生成并保存snapshot文件
  - 修复测试中发现的问题
- **Acceptance Criteria Addressed**: AC-10
- **Test Requirements**:
  - `programmatic` TR-5.1: nf-test --stub模式测试通过
  - `programmatic` TR-5.2: main.nf.test.snap文件生成且包含正确的快照
  - `programmatic` TR-5.3: 所有assertAll断言通过
- **Notes**: 确保stub输出与实际输出格式一致

## [x] Task 6: Docker环境测试验证（可选）
- **Priority**: medium
- **Depends On**: Task 5
- **Description**: 
  - 使用真实Docker环境运行测试（需要网络）
  - 验证fastq-dl可以正常下载数据
  - 验证输出文件格式正确
  - 验证--platform linux/amd64配置正常工作
- **Acceptance Criteria Addressed**: AC-3, AC-5, AC-11
- **Test Requirements**:
  - `programmatic` TR-6.1: Docker镜像可以正常拉取和启动（带--platform linux/amd64）
  - `programmatic` TR-6.2: fastq-dl --version输出正确版本号（v4.0.1）
  - `programmatic` TR-6.3: 下载的FASTQ文件格式正确（gz压缩）
  - `programmatic` TR-6.4: run-info.tsv和run-mergers.tsv文件正常生成
- **Notes**: 需要网络连接，测试可能需要较长时间。如网络不可用可跳过。
