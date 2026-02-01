process FLAIR_VARIANTS {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/flair:3.0.0b1--pyhdfd78af_0' :
        'docker.1ms.run/brookslab/flair:3.0.0' }"

    input:
    tuple val(meta), path(manifest), path(bams), path(isoforms_bed), path(isoforms_fa)
    tuple path(genome), path(fai)
    path(gtf)

    output:
    tuple val(meta), path("*.vcf"), emit: variants
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def isoforms_fa_name = isoforms_fa instanceof List ? isoforms_fa[0] : isoforms_fa
    """
    flair variants \\
        -m ${manifest} \\
        -b $isoforms_bed \
        -i $isoforms_fa_name \
        -g $genome \
        -f $gtf \\
        -o ${prefix} \\
        $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        flair: \$(flair --version | sed 's/flair //')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.vcf

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        flair: \$(flair --version | sed 's/flair //')
    END_VERSIONS
    """
}
