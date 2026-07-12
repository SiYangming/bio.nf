include { SRATOOLS_FASTERQDUMP } from './fasterqdump/main.nf'

process COPY_OUTPUT {
    tag "$meta.id"
    label 'process_low'

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path('*.fastq.gz')

    script:
    def out_dir = "${params.outdir}/${meta.id}"
    """
    mkdir -p ${out_dir}
    cp *.fastq.gz ${out_dir}/
    """
}

workflow {
    Channel
        .fromPath(params.sra_dir + '/*/*.sra', checkIfExists: true)
        .map { file ->
            def sra_id = file.parent.name
            return [
                [id: sra_id, single_end: false],
                file
            ]
        }
        .set { sra_files }

    SRATOOLS_FASTERQDUMP(
        sra_files,
        file('modules/sratools/ncbi-settings.xml'),
        file('empty')
    )

    COPY_OUTPUT(SRATOOLS_FASTERQDUMP.out.reads)

    COPY_OUTPUT.out
        .view { meta, reads ->
            println "Copied ${meta.id} to ${params.outdir}/${meta.id}: ${reads.size()} files"
        }
}