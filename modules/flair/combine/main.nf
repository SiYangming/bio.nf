process FLAIR_COMBINE {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/flair:3.0.0b1--pyhdfd78af_0' :
        'docker.1ms.run/brookslab/flair:3.0.0' }"

    input:
    tuple val(meta), path(manifest), path(input_files)

    output:
    tuple val(meta), path("*.bed"), emit: bed
    tuple val(meta), path("*.fa") , emit: fasta, optional: true
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    flair combine \\
        -m $manifest \\
        -o ${prefix}.combined.bed \\
        $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        flair: \$(flair --version | sed 's/flair //')
    END_VERSIONS
    """
}
