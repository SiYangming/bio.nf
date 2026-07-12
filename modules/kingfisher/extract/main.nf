process KINGFISHER_EXTRACT {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/kingfisher:0.4.1--pyh7cba7a3_0' :
        'quay.io/biocontainers/kingfisher:0.4.1--pyh7cba7a3_0' }"

    input:
    tuple val(meta), path(sra)

    output:
    tuple val(meta), path("*.fastq.gz"), emit: fastq
    path "versions.yml"                , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    kingfisher extract \\
        --sra ${sra} \\
        -t ${task.cpus} \\
        -f fastq.gz \\
        $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        kingfisher: \$(kingfisher --version | sed 's/kingfisher //')
    END_VERSIONS
    """

    stub:
    """
    echo "" | gzip > ${sra.baseName}_1.fastq.gz
    echo "" | gzip > ${sra.baseName}_2.fastq.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        kingfisher: 0.4.1
    END_VERSIONS
    """
}
