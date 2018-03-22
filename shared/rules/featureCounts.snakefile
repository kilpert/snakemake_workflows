
## featurecounts (paired options are inserted conditionally)

rule featureCounts:
    input:
        bam = mapping_prg+"/{sample}.bam",
        anno = genes_gtf
    output:
        "featureCounts/{sample}.counts.txt"
    params:
        libtype = library_type,
        paired_opt = lambda wildcards: "-p -B " if paired else "",
        opts = config["featurecounts_options"],
    log:
        "featureCounts/{sample}.log"
    threads: 8
    shell:
        feature_counts_path+"featureCounts "
        "{params.paired_opt}{params.opts} "
        "-T {threads} "
        "-s {params.libtype} "
        "-a {input.anno} "
        "-o {output} "
        "--tmpDir ${{TMPDIR}} "
        "{input.bam} &>> {log} "

rule merge_featureCounts:
    input:
        expand("featureCounts/{sample}.counts.txt", sample=samples)
    output:
        "featureCounts/counts.tsv"
    shell:
        R_path+"Rscript "+os.path.join(maindir, "shared", "tools", "merge_featureCounts.R")+" {output} {input}"
