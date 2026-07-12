include { SRATOOLS_FASTERQDUMP } from './fasterqdump/main.nf'

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

    SRATOOLS_FASTERQDUMP.out.reads
        .map { meta, reads ->
            return [meta, reads]
        }
        .view { meta, reads ->
            println "Converted ${meta.id}: ${reads.size()} files"
        }
}