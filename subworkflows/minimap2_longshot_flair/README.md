# minimap2_longshot_flair

A subworkflow to align long reads with Minimap2, call variants with Longshot, and run Flair variants for isoform quantification.

## Introduction

This subworkflow implements the pipeline logic corresponding to:
1. Align reads to reference genome using `minimap2`.
2. Call SNVs using `longshot`.
3. Create a manifest file linking BAM and VCF.
4. Call variants/isoforms using `flair variants`.

## Usage

```groovy
include { FLAIR_LONGSHOT } from './subworkflows/minimap2_longshot_flair/main'

workflow {
    // Define inputs
    ch_reads = ...         // [ [meta], reads ]
    ch_genome = ...        // [ [meta], fasta, fai ]
    ch_quant_bam = ...     // [ [meta], bam ] (for quantification/manifest)
    ch_isoforms_fa = ...   // [ [meta], fasta ]
    ch_isoforms_bed = ...  // [ [meta], bed ]
    ch_gtf = ...           // [ gtf ]

    FLAIR_LONGSHOT (
        ch_reads,
        ch_genome,
        ch_quant_bam,
        ch_isoforms_fa,
        ch_isoforms_bed,
        ch_gtf
    )
}
```

## Inputs

* `ch_reads`: Channel containing read files.
* `ch_genome`: Channel containing reference genome and index.
* `ch_quant_bam`: Channel containing BAM files for quantification (usually same as aligned or separate).
* `ch_isoforms_fa`: Channel containing isoforms FASTA.
* `ch_isoforms_bed`: Channel containing isoforms BED.
* `ch_gtf`: Channel containing GTF annotation.

## Outputs

* `variants`: VCF file containing called variants from Flair.
* `versions`: File containing software versions.

## Tests

Run the test suite:

```bash
nf-test test subworkflows/minimap2_longshot_flair/tests/main.nf.test
```
