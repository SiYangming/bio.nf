//
// Subworkflow to call variants using Longshot and run Flair variants
//

include { MINIMAP2_ALIGN } from '../../modules/minimap2/align/main'
include { MINIMAP2_ALIGN as MINIMAP2_ALIGN_TRANSCRIPTOME } from '../../modules/minimap2/align/main'
include { LONGSHOT }       from '../../modules/longshot/main'
include { FLAIR_VARIANTS } from '../../modules/flair/variants/main'
include { SAMTOOLS_FAIDX } from '../../modules/samtools/faidx/main'

workflow MINIMAP2_LONGSHOT_FLAIR {
    take:
    ch_reads         // channel: [ val(meta), [ reads ] ]
    ch_genome        // channel: [ val(meta), fasta, fai ]
    ch_isoforms_fa   // channel: [ val(meta), fasta ]
    ch_isoforms_bed  // channel: [ val(meta), bed ]
    ch_gtf           // channel: [ gtf ]

    main:
    ch_versions = Channel.empty()

    //
    // 0. Filter Isoforms Fasta to match BED
    //
    ch_filter_input = ch_isoforms_fa.join(ch_isoforms_bed) // [meta, fa, bed]

    FILTER_FASTA (
        ch_filter_input
    )
    ch_filtered_isoforms_fa = FILTER_FASTA.out.fasta // [meta, filtered_fa]
    ch_versions = ch_versions.mix(FILTER_FASTA.out.versions)

    //
    // 1. Align reads to genome
    //
    MINIMAP2_ALIGN (
        ch_reads,
        ch_genome.map { [it[0], it[1]] }, // [meta, fasta]
        true, // bam_format
        'bai', // bam_index_extension
        false, // cigar_paf_format
        false  // cigar_bam
    )
    ch_versions = ch_versions.mix(MINIMAP2_ALIGN.out.versions)

    //
    // 1b. Align reads to transcriptome (for Flair Variants)
    //
    MINIMAP2_ALIGN_TRANSCRIPTOME (
        ch_reads,
        ch_filtered_isoforms_fa,
        true, // bam_format
        'bai', // bam_index_extension
        false, // cigar_paf_format
        false  // cigar_bam
    )
    ch_versions = ch_versions.mix(MINIMAP2_ALIGN_TRANSCRIPTOME.out.versions)

    //
    // 2. Index isoforms fasta
    //
    SAMTOOLS_FAIDX (
        ch_filtered_isoforms_fa,
        [[], []], // Optional fasta_fai input (not needed here as we are indexing)
        false
    )
    // ch_versions = ch_versions.mix(SAMTOOLS_FAIDX.out.versions)


    //
    // 3. Call variants with Longshot
    //
    ch_longshot_input = MINIMAP2_ALIGN.out.bam.join(MINIMAP2_ALIGN.out.index)
    
    LONGSHOT (
        ch_longshot_input,
        ch_genome,
        "" // region
    )
    ch_versions = ch_versions.mix(LONGSHOT.out.versions)

    //
    // 4. Create manifest for Flair
    //
    // Using the aligned BAM from MINIMAP2_TRANSCRIPTOME as the BAM input for Flair
    // Need BAM (transcriptome), and VCF (genome).
    ch_transcriptome_bam = MINIMAP2_ALIGN_TRANSCRIPTOME.out.bam.join(MINIMAP2_ALIGN_TRANSCRIPTOME.out.index)
    ch_manifest_input = ch_transcriptome_bam.join(LONGSHOT.out.vcf)
    
    CREATE_MANIFEST ( ch_manifest_input.map { meta, bam, bai, vcf -> [meta, bam, vcf] } )
    // No versions for CREATE_MANIFEST as it's a local helper

    //
    // 5. Run Flair variants
    //
    // Join all inputs: manifest, bam, bai, vcf, bed, fa (with index)
    ch_isoforms_fa_with_index = ch_filtered_isoforms_fa
        .join(SAMTOOLS_FAIDX.out.fai)
        .map { meta, fa, fai -> [ meta, [fa, fai] ] }

    ch_flair_inputs = CREATE_MANIFEST.out.manifest
        .join(ch_manifest_input) // [meta, manifest, bam, bai, vcf]
        .join(ch_isoforms_bed)   // [meta, manifest, bam, bai, vcf, bed]
        .join(ch_isoforms_fa_with_index)    // [meta, manifest, bam, bai, vcf, bed, [fa, fai]]
        .map { meta, manifest, bam, bai, vcf, bed, fa_list ->
            [ meta, manifest, [bam, bai, vcf], bed, fa_list ]
        }

    FLAIR_VARIANTS (
        ch_flair_inputs,
        ch_genome.map { [it[1], it[2]] },
        ch_gtf
    )
    ch_versions = ch_versions.mix(FLAIR_VARIANTS.out.versions)

    emit:
    variants = FLAIR_VARIANTS.out.variants
    versions = ch_versions
}

process CREATE_MANIFEST {
    tag "$meta.id"
    executor 'local'
    
    input:
    tuple val(meta), path(bam), path(vcf)
    
    output:
    tuple val(meta), path("*.tsv"), emit: manifest
    
    script:
    """
    echo "${meta.id}\t${bam}\t${vcf}" > ${meta.id}.manifest.tsv
    """
}

process FILTER_FASTA {
    tag "$meta.id"
    label 'process_low'
    
    conda "bioconda::samtools=1.17"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/samtools:1.17--h00cdaf9_0' :
        'biocontainers/samtools:1.17--h00cdaf9_0' }"

    input:
    tuple val(meta), path(fasta), path(bed)

    output:
    tuple val(meta), path("*.filtered.fa"), emit: fasta
    path "versions.yml"                   , emit: versions

    script:
    """
    # Extract isoform IDs from BED (column 4)
    awk '{print \$4}' ${bed} | sort | uniq > ids.txt
    
    # Filter FASTA
    awk 'NR==FNR{ids[\$1]; next} /^>/{header=substr(\$1,2); keep=(header in ids)} keep' ids.txt ${fasta} > ${meta.id}.filtered.fa
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        awk: \$(awk --version | head -n 1 | sed 's/GNU Awk //; s/, API.*//')
    END_VERSIONS
    """
}
