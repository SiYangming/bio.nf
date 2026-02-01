include { FLAIR_ALIGN    } from '../../modules/flair/align/main'
include { FLAIR_CORRECT  } from '../../modules/flair/correct/main'
include { FLAIR_COLLAPSE } from '../../modules/flair/collapse/main'

workflow FLAIR_ANALYSIS {

    take:
    ch_reads   // [ val(meta), path(reads) ]
    ch_genome  // [ val(meta), path(genome) ]
    ch_gtf     // [ val(meta), path(gtf) ]

    main:

    ch_versions = Channel.empty()

    FLAIR_ALIGN ( ch_reads, ch_genome )
    ch_versions = ch_versions.mix(FLAIR_ALIGN.out.versions_flair)

    FLAIR_CORRECT ( FLAIR_ALIGN.out.bed, ch_gtf )
    ch_versions = ch_versions.mix(FLAIR_CORRECT.out.versions_flair)

    FLAIR_COLLAPSE ( ch_reads, FLAIR_CORRECT.out.bed, ch_genome, ch_gtf )
    ch_versions = ch_versions.mix(FLAIR_COLLAPSE.out.versions_flair)

    emit:
    bam          = FLAIR_ALIGN.out.bam             // channel: [ val(meta), path(bam) ]
    bed          = FLAIR_CORRECT.out.bed           // channel: [ val(meta), path(bed) ]
    isoforms_bed = FLAIR_COLLAPSE.out.isoforms_bed // channel: [ val(meta), path(bed) ]
    isoforms_gtf = FLAIR_COLLAPSE.out.isoforms_gtf // channel: [ val(meta), path(gtf) ]
    isoforms_fa  = FLAIR_COLLAPSE.out.isoforms_fa  // channel: [ val(meta), path(fasta) ]

    versions     = ch_versions                     // channel: [ path(versions.yml) ]
}
