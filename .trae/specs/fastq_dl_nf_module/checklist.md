# fastq-dl Nextflow模块 - 验证清单

## 文件结构验证
- [x] 模块目录 modules/fastqdl/download/ 存在
- [x] main.nf 文件存在且语法正确
- [x] meta.yml 文件存在且格式正确
- [x] environment.yml 文件存在且包含正确的依赖
- [x] tests/ 目录存在
- [x] tests/main.nf.test 文件存在
- [x] tests/nextflow.config 文件存在
- [x] modules/fastqdl/sra_ids_test.csv 测试数据文件存在

## Process定义验证
- [x] process名称为 FASTQDL_DOWNLOAD（全大写）
- [x] tag使用 $meta.id
- [x] label设置为 'process_medium'
- [x] 包含 when 块支持 task.ext.when

## 环境配置验证
- [x] conda配置指向 ${moduleDir}/environment.yml
- [x] Docker镜像为 quay.io/biocontainers/fastq-dl:4.0.1--pyhdfd78af_0
- [x] Singularity配置正确（Galaxy镜像或docker镜像转换）
- [x] environment.yml包含 bioconda::fastq-dl=4.0.1
- [x] tests/nextflow.config 中 docker.runOptions 设置为 '--platform linux/amd64'

## 输入输出验证
- [x] 输入为 tuple val(meta), val(accession)
- [x] 输出 fastq 通道（*.fastq.gz）带 emit: fastq
- [x] 输出 versions 通道（versions.yml）带 emit: versions
- [x] 输出 run_info 通道（*-run-info.tsv）带 emit: run_info
- [x] 输出 run_mergers 通道（*-run-mergers.tsv）带 emit: run_mergers
- [x] meta.yml中input/output描述与main.nf一致

## 功能验证
- [x] script块使用 fastq-dl --accession 命令
- [x] 支持 --outdir 参数设置为当前目录
- [x] 使用 task.ext.args 传递额外参数
- [x] 使用 task.ext.prefix 定义输出前缀（默认meta.id）
- [x] versions.yml文件格式正确（YAML格式，包含版本号）
- [x] stub块生成模拟的FASTQ.gz文件
- [x] stub块生成模拟的run-info.tsv文件
- [x] stub块生成模拟的run-mergers.tsv文件
- [x] stub块生成模拟的versions.yml文件

## 测试验证
- [x] 测试用例使用modules/fastqdl/sra_ids_test.csv中的数据
- [x] 至少包含一个stub模式测试用例
- [x] 测试用例包含assertAll断言
- [x] snapshot测试文件 main.nf.test.snap 存在
- [x] nf-test stub模式运行成功
- [x] Docker环境测试通过（fastq-dl 4.0.1版本正确）

## 文档验证
- [x] meta.yml包含name字段
- [x] meta.yml包含description字段
- [x] meta.yml包含keywords字段
- [x] meta.yml包含tools字段（含homepage, licence等）
- [x] meta.yml包含完整的input描述
- [x] meta.yml包含完整的output描述（含run_mergers）
- [x] meta.yml包含authors和maintainers

## 代码风格验证
- [x] 代码风格与现有nf-core模块一致
- [x] 变量命名规范
- [x] 缩进正确（4空格）
- [x] 无多余的注释或调试代码
