include { SRATOOLS_FASTERQDUMP } from './fasterqdump/main.nf'

process COPY_OUTPUT {
    label 'process_low'

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path('*.fastq.gz')

    script:
    """
    for f in *.fastq; do
        cat "\$f" > "\${f}.tmp"
        mv "\${f}.tmp" "\$f"
    done
    pigz --no-name --processes $task.cpus *.fastq
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
        .subscribe { meta, reads ->
            def out_dir = "${params.outdir}/${meta.id}"
            new File(out_dir).mkdirs()
            reads.each { read ->
                def dest = new File(out_dir, read.getName())
                java.nio.file.Files.copy(read, dest.toPath(), java.nio.file.StandardCopyOption.REPLACE_EXISTING)
            }
            println "Copied ${meta.id} to ${out_dir}: ${reads.size()} files"
        }
}