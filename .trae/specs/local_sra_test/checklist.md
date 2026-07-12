# SRA to FASTQ 本地测试 - 验证检查清单

- [ ] Checkpoint 1: 测试目录 `/Users/siyangming/test_sra/ERR6326076/` 存在
- [ ] Checkpoint 2: ERR6326076.sra 文件存在于测试目录
- [ ] Checkpoint 3: Nextflow 流程成功完成（退出码为 0）
- [ ] Checkpoint 4: 输出目录 `/Users/siyangming/test_eccDNA/ERR6326076/` 存在
- [ ] Checkpoint 5: 输出目录中有 `.fastq.gz` 文件
- [ ] Checkpoint 6: FASTQ 文件大小 > 0 bytes
- [ ] Checkpoint 7: FASTQ 文件内容格式正确（@开头的序列头）
- [ ] Checkpoint 8: 单端/双端数据处理逻辑修复有效