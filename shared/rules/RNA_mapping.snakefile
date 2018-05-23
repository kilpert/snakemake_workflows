
### HISAT2 #####################################################################

if mapping_prg.upper().find("HISAT2") >=0:
    if paired:
        rule HISAT2:
            input:
                r1 = fastq_dir+"/{sample}"+reads[0]+".fastq.gz",
                r2 = fastq_dir+"/{sample}"+reads[1]+".fastq.gz"
            output:
                align_summary = mapping_prg+"/{sample}.HISAT2_summary.txt",
                bam = temp(mapping_prg+"/{sample}.sorted.bam"),
                splice = mapping_prg+"/{sample}/splice_sites.txt",
                met = mapping_prg+"/{sample}/metrics.txt",
                unconc = mapping_prg+"/{sample}/un-conc.fastq.gz",
                alconc = mapping_prg+"/{sample}/al-conc.fastq.gz"
            params:
                input_splice = known_splicesites,
                hisat_options = str(hisat_options or ''),
                rna_strandness = rna_strandness,
                samsort_memory = '2G'
            benchmark:
                mapping_prg+"/.benchmark/HISAT2.{sample}.benchmark"
            threads: 10
            resources:
                mem_mb=4000
            conda: CONDA_RNASEQ_ENV
            shell:
                "hisat2 "
                "-p {threads} "
                "{params.hisat_options} "
                "{params.rna_strandness} "
                "-x "+hisat2_index+" "
                "--known-splicesite-infile {params.input_splice} "
                "-1 {input.r1} -2 {input.r2} "
                "--novel-splicesite-outfile {output.splice} "
                "--met-file {output.met} "
                "--un-conc-gz {output.unconc} "
                "--al-conc-gz {output.alconc} "
                "2> {output.align_summary} | "
                "samtools view -Sb - | "
                "samtools sort -m {params.samsort_memory} "
                "-T ${{TMPDIR}}{wildcards.sample} -@ {threads} -O bam - > {output.bam} "
                "&& touch {output.unconc} {output.alconc} "
    else:
        rule HISAT2:
            input:
                fastq_dir+"/{sample}.fastq.gz"
            output:
                align_summary = mapping_prg+"/{sample}.HISAT2_summary.txt",
                bam = temp(mapping_prg+"/{sample}.sorted.bam"),
                splice = mapping_prg+"/{sample}/splice_sites.txt",
                met = mapping_prg+"/{sample}/metrics.txt",
                un = mapping_prg+"/{sample}/un.fastq.gz",
                al = mapping_prg+"/{sample}/al.fastq.gz"
            params:
                input_splice = known_splicesites,
                hisat_options = str(hisat_options or ''),
                rna_strandness = rna_strandness,
                samsort_memory = '2G'
            benchmark:
                mapping_prg+"/.benchmark/HISAT2.{sample}.benchmark"
            threads: 10
            conda: CONDA_RNASEQ_ENV
            shell:
                "hisat2 "
                "-p {threads} "
                "{params.hisat_options} "
                "{params.rna_strandness} "
                "-x "+hisat2_index+" "
                "--known-splicesite-infile {params.input_splice} "
                "-U {input} "
                "--novel-splicesite-outfile {output.splice} "
                "--met-file {output.met} "
                "--un-gz {output.un} "
                "--al-gz {output.al} "
                "2> {output.align_summary} | "
                "samtools view -Sb - | "
                "samtools sort -m {params.samsort_memory} "
                "-T ${{TMPDIR}}{wildcards.sample} -@ {threads} -O bam - > {output.bam} "
                "&& touch {output.un} {output.al} "


elif mapping_prg.upper().find("STAR") >=0:
    if paired:
        rule STAR:
            input:
                r1 = fastq_dir+"/{sample}"+reads[0]+".fastq.gz",
                r2 = fastq_dir+"/{sample}"+reads[1]+".fastq.gz"
            output:
                bam = temp(mapping_prg+"/{sample}.sorted.bam")
            params:
                star_options = str(star_options or ''),
                gtf = genes_gtf,
                index = star_index,
                prefix = mapping_prg+"/{sample}/{sample}.",
                sample_dir = mapping_prg+"/{sample}"
            benchmark:
                mapping_prg+"/.benchmark/STAR.{sample}.benchmark"
            threads: 12
            conda: CONDA_RNASEQ_ENV
            shell:
                "( [ -d {params.sample_dir} ] || mkdir -p {params.sample_dir} ) && "
                "STAR "
                "--runThreadN {threads} "
                "{params.star_options} "
                "--sjdbOverhang 100 "
                "--readFilesCommand zcat "
                "--outSAMunmapped Within "
                "--outSAMtype BAM SortedByCoordinate "
                "--sjdbGTFfile {params.gtf} "
                "--genomeDir {params.index} "
                "--readFilesIn {input.r1} {input.r2} "
                "--outFileNamePrefix {params.prefix} "
                "&& mv {params.prefix}Aligned.sortedByCoord.out.bam {output.bam} "
    else:
        rule STAR:
            input:
                fastq_dir+"/{sample}.fastq.gz"
            output:
                bam = temp(mapping_prg+"/{sample}.sorted.bam")
            params:
                star_options = str(star_options or ''),
                gtf = genes_gtf,
                index = star_index,
                prefix = mapping_prg+"/{sample}/{sample}.",
                sample_dir = mapping_prg+"/{sample}"
            benchmark:
                mapping_prg+"/.benchmark/STAR.{sample}.benchmark"
            threads: 12
            conda: CONDA_RNASEQ_ENV
            shell:
                "( [ -d {params.sample_dir} ] || mkdir -p {params.sample_dir} ) && "
                "STAR "
                "--runThreadN {threads} "
                "{params.star_options} "
                "--sjdbOverhang 100 "
                "--readFilesCommand zcat "
                "--outSAMunmapped Within "
                "--outSAMtype BAM SortedByCoordinate "
                "--sjdbGTFfile {params.gtf} "
                "--genomeDir {params.index} "
                "--readFilesIn {input} "
                "--outFileNamePrefix {params.prefix} "
                "&& mv {params.prefix}Aligned.sortedByCoord.out.bam {output.bam} "
