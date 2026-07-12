process FASTQDL_DOWNLOAD {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/fastq-dl:4.0.1--pyhdfd78af_0' :
        'quay.io/biocontainers/fastq-dl:4.0.1--pyhdfd78af_0' }"

    input:
    tuple val(meta), val(accession)

    output:
    tuple val(meta), path("*.fastq.gz")    , emit: fastq
    path "versions.yml"                   , emit: versions
    tuple val(meta), path("*-run-info.tsv")   , emit: run_info
    tuple val(meta), path("*-run-mergers.tsv"), emit: run_mergers

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    fastq-dl \\
        --accession ${accession} \\
        --outdir ./ \\
        --prefix ${prefix} \\
        $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        fastq-dl: \$(fastq-dl --version | sed 's/fastq-dl //')
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo "" | gzip > ${accession}_1.fastq.gz
    echo "" | gzip > ${accession}_2.fastq.gz

    touch ${prefix}-run-info.tsv
    touch ${prefix}-run-mergers.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        fastq-dl: 4.0.1
    END_VERSIONS
    """
}
