# longshot

Longshot: Long-read SNV caller

## Introduction

Longshot is a variant caller for long read data (Oxford Nanopore, PacBio, etc.).

Official Documentation: [https://github.com/pjedge/longshot](https://github.com/pjedge/longshot)

## Usage

```groovy
include { LONGSHOT } from './modules/longshot/main'

workflow {
    input = [ [ id:'test' ], file('sample.bam'), file('sample.bam.bai') ]
    fasta = [ [ id:'genome' ], file('genome.fa'), file('genome.fa.fai') ]
    region = "chr20:1000-2000" // or null/""

    LONGSHOT ( input, fasta, region )
}
```

## Inputs

* `bam`: Input BAM file (must be indexed)
* `fasta`: Reference genome FASTA file (must be indexed)
* `region`: Optional region string (e.g. `chr20:1000-2000`)

## Outputs

* `vcf`: Output VCF file
* `versions`: Software versions

## Performance Benchmarks

Time and memory usage depend on the coverage and region size.
For a small region (e.g. 50kb) and 30x coverage:
* Time: ~1-2 minutes
* Memory: ~1-2 GB
