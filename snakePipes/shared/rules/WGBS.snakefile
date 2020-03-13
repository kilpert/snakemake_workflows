import os
import re
from operator import is_not
import tempfile

###symlink bams if this is the starting point
if fromBAM:
    rule link_bam:
        input:
            indir + "/{sample}" + bamExt
        output:
            "bwameth/{sample}.sorted" + bamExt
        shell:
            "( [ -f {output} ] || ln -s -r {input} {output} ) "

# TODO: Make optional
rule conversionRate:
    input:
        "QC_metrics/{sample}.CHH.Mbias.txt"
    output:
        "QC_metrics/{sample}.conv.rate.txt"
    threads: 1
    shell: """
        awk '{{if(NR>1) {{M+=$4; UM+=$5}}}}END{{printf("{wildcards.sample}\\t%f\\n", 100*(1.0-M/(M+UM)))}}' {input} > {output}
        """


### bwameth ##########################################
if pairedEnd and not fromBAM:
    rule bwameth:
        input:
            r1=fastq_dir + "/{sample}" + reads[0] + ".fastq.gz",
            r2=fastq_dir + "/{sample}" + reads[1] + ".fastq.gz"
        output:
            sbam=temp("bwameth/{sample}.sorted.bam")
        log:
            err="bwameth/logs/{sample}.map_reads.err",
            out="bwameth/logs/{sample}.map_reads.out"
        params:
            bwameth_index=bwameth_index
        threads: 20
        conda: CONDA_WGBS_ENV
        shell: """
            MYTEMP=$(mktemp -d "${{TMPDIR:-/tmp}}"/snakepipes.XXXXXXXXXX)
            bwameth.py --threads {threads} --reference "{params.bwameth_index}" "{input.r1}" "{input.r2}" 2> {log.err} | \
	        samtools sort -T "$MYTEMP"/{wildcards.sample} -m 3G -@ 4 -o "{output.sbam}"
            rm -rf "$MYTEMP"
            """
elif not fromBAM:
    rule bwameth:
        input:
            r1=fastq_dir + "/{sample}" + reads[0] + ".fastq.gz",
        output:
            sbam=temp("bwameth/{sample}.sorted.bam")
        log:
            err="bwameth/logs/{sample}.map_reads.err",
            out="bwameth/logs/{sample}.map_reads.out"
        params:
            bwameth_index=bwameth_index
        threads: 20
        conda: CONDA_WGBS_ENV
        shell: """
            MYTEMP=$(mktemp -d "${{TMPDIR:-/tmp}}"/snakepipes.XXXXXXXXXX)
            bwameth.py --threads {threads} --reference "{params.bwameth_index}" "{input.r1}" 2> {log.err} | \
	        samtools sort -T "$MYTEMP/{wildcards.sample}" -m 3G -@ 4 -o "{output.sbam}"
            rm -rf "$MYTEMP"
            """

rule index_bam:
    input:
        "bwameth/{sample}.sorted.bam"
    output:
        temp("bwameth/{sample}.sorted.bam.bai")
    log:
        err="bwameth/logs/{sample}.index_bam.err",
        out="bwameth/logs/{sample}.index_bam.out"
    conda: CONDA_SHARED_ENV
    shell: """
        samtools index "{input}" >{log.out} 2>{log.err}
        """


rule markDupes:
    input:
        "bwameth/{sample}.sorted.bam",
        "bwameth/{sample}.sorted.bam.bai"
    output:
        "bwameth/{sample}.markdup.bam"
    log:
        err="bwameth/logs/{sample}.rm_dupes.err",
        out="bwameth/logs/{sample}.rm_dupes.out"
    threads: 10
    conda: CONDA_SAMBAMBA_ENV
    shell: """
        MYTEMP=$(mktemp -d "${{TMPDIR:-/tmp}}"/snakepipes.XXXXXXXXXX)
        sambamba markdup -t {threads} --tmpdir "$MYTEMP/{wildcards.sample}" "{input[0]}" "{output}" >{log.out} 2>{log.err}
        rm -rf "$MYTEMP"
        """


rule indexMarkDupes:
    input:
        "bwameth/{sample}.markdup.bam"
    output:
        "bwameth/{sample}.markdup.bam.bai"
    params:
    log:
        err="bwameth/logs/{sample}.indexMarkDupes.err",
        out="bwameth/logs/{sample}.indexMarkDupes.out"
    threads: 1
    conda: CONDA_SHARED_ENV
    shell: """
        samtools index "{input}" 1>{log.out} 2>{log.err}
        """


rule getRandomCpGs:
    output:
        temp("QC_metrics/randomCpG.bed")
    params:
        genome_fasta=genome_fasta
    run:
        import random
        random.seed(1234)  # Just to ensure reproducibility

        buf = []
        maxLen = 1000000  # In theory this could be changed
        chroms = []
        position = 0
        chars = 0
        lastChar = 'N'

        def addPosition(B, tid, pos, n):
            if len(B) < maxLen:
                B.append((tid, pos))
            else:
                x = random.randint(0, n)
                if x < maxLen:
                    B[x] = (tid, pos)

        for line in open(params['genome_fasta']):
            line = line.strip().split()[0]
            if line.startswith(">"):
                chroms.append(line[1:])
                lastChar = 'N'
                position = 0
                continue
            for c in line:
                if (lastChar == 'C' or lastChar == 'c') and (c == 'G' or c == 'g'):
                    addPosition(buf, len(chroms) - 1, position - 1, chars)
                    lastChar = 'N'
                    chars += 1
                else:
                    lastChar = c
                position += 1

        # Sort
        buf.sort()

        # write output
        if len(buf):
            o = open(output[0], "w")
            for tid, pos in buf:
                o.write("{}\t{}\t{}\n".format(chroms[tid], pos, pos + 2))
            o.close()


rule calc_Mbias:
    input:
        "bwameth/{sample}.markdup.bam",
        "bwameth/{sample}.markdup.bam.bai"
    output:
        "QC_metrics/{sample}.Mbias.txt"
    params:
        genome=genome_fasta
    log:
        out="QC_metrics/logs/{sample}.calc_Mbias.out"
    threads: 10
    conda: CONDA_WGBS_ENV
    shell: """
        MethylDackel mbias -@ {threads} {params.genome} {input[0]} QC_metrics/{wildcards.sample} 2> {output} > {log.out}
        """


rule calcCHHbias:
    input:
        "bwameth/{sample}.markdup.bam",
        "bwameth/{sample}.markdup.bam.bai"
    output:
        temp("QC_metrics/{sample}.CHH.Mbias.txt")
    params:
        genome=genome_fasta
    log:
        err="QC_metrics/logs/{sample}.calcCHHbias.err"
    threads: 10
    conda: CONDA_WGBS_ENV
    shell: """
        MethylDackel mbias -@ {threads} --CHH --noCpG --noSVG {params.genome} {input[0]} QC_metrics/{wildcards.sample} > {output} 2> {log.err}
        """


rule calc_GCbias:
    input:
        BAMS=expand("bwameth/{sample}.markdup.bam", sample=samples),
        BAIS=expand("bwameth/{sample}.markdup.bam.bai", sample=samples),
    output:
        "QC_metrics/GCbias.freq.txt",
        "QC_metrics/GCbias." + plotFormat
    params:
        genomeSize=genome_size,
        twobitpath=genome_2bit
    log:
        out="QC_metrics/logs/calc_GCbias.out"
    threads: 20
    conda: CONDA_SHARED_ENV
    shell: """
        computeGCBias -b {input.BAMS} --effectiveGenomeSize {params.genomeSize} -g {params.twobitpath} -l 300 --GCbiasFrequenciesFile {output[0]} -p {threads} --biasPlot {output[1]}
        """


rule DepthOfCov:
    input:
        BAMS=expand("bwameth/{sample}.markdup.bam", sample=samples),
        BAIS=expand("bwameth/{sample}.markdup.bam.bai", sample=samples),
        BED="QC_metrics/randomCpG.bed"
    output:
        "QC_metrics/CpGCoverage.txt",
        "QC_metrics/CpGCoverage.png",
        "QC_metrics/CpGCoverage.coverageMetrics.txt"
    params:
        options="--minMappingQuality 10 --smartLabels --samFlagExclude 256",
        thresholds="-ct 0 -ct 1 -ct 2 -ct 5 -ct 10 -ct 15 -ct 20 -ct 30 -ct 50"
    threads: 20
    log:
        err="QC_metrics/logs/DepthOfCov.err"
    conda: CONDA_SHARED_ENV
    shell: """
        plotCoverage -b {input.BAMS} -p {threads} --outCoverageMetrics {output[2]} --BED {input.BED} \
            {params.thresholds} {params.options} -o {output[1]} > {output[0]} 2> {log.err}
        """


rule DepthOfCovGenome:
    input:
        BAMS=expand("bwameth/{sample}.markdup.bam", sample=samples),
        BAIS=expand("bwameth/{sample}.markdup.bam.bai", sample=samples)
    output:
        "QC_metrics/genomeCoverage.txt",
        "QC_metrics/genomeCoverage.png",
        "QC_metrics/genomeCoverage.coverageMetrics.txt"
    params:
        options="--minMappingQuality 10 --smartLabels --samFlagExclude 256",
        thresholds="-ct 0 -ct 1 -ct 2 -ct 5 -ct 10 -ct 15 -ct 20 -ct 30 -ct 50"
    threads: 20
    log:
        err="QC_metrics/logs/DepthOfCovGenome.err"
    conda: CONDA_SHARED_ENV
    shell: """
        plotCoverage -b {input.BAMS} -p {threads} {params.thresholds} {params.options} --outCoverageMetrics {output[2]} -o {output[1]} > {output[0]} 2> {log.err}
        """


rule get_flagstat:
    input:
        "bwameth/{sample}.markdup.bam"
    output:
        "QC_metrics/{sample}.flagstat"
    log:
        err="QC_metrics/logs/{sample}.get_flagstat.err"
    threads: 1
    conda: CONDA_SHARED_ENV
    shell: "samtools flagstat {input} > {output} 2>{log.err}"


rule produceReport:
    input:
        bedGraphs=expand("MethylDackel/{sample}_CpG.bedGraph", sample=samples),
        Coverage=calc_doc(skipDOC),
        ConversionRate=expand("QC_metrics/{sample}.conv.rate.txt", sample=samples),
        mbiasTXT=expand("QC_metrics/{sample}.Mbias.txt", sample=samples),
        fstat=expand("QC_metrics/{sample}.flagstat", sample=samples)
    output:
        QCrep='QC_metrics/QC_report.html'
    params:
        auxdir=os.path.join(outdir, "QC_metrics"),
        minCoverage=minCoverage
    conda: CONDA_WGBS_ENV
    script: "../rscripts/WGBS_QC_report_template.Rmd"


if not noAutoMethylationBias:
    rule methyl_extract:
        input:
            "bwameth/{sample}.markdup.bam",
            "bwameth/{sample}.markdup.bam.bai",
            "QC_metrics/{sample}.Mbias.txt"
        output:
            "MethylDackel/{sample}_CpG.bedGraph"
        params:
            genome=genome_fasta,
            MethylDackelOptions=MethylDackelOptions
        log:
            err="MethylDackel/logs/{sample}.methyl_extract.err",
            out="MethylDackel/logs/{sample}.methyl_extract.out"
        threads: 10
        conda: CONDA_WGBS_ENV
        shell: """
            mi=$(cat {input[2]} | sed 's/Suggested inclusion options: //' )
            MethylDackel extract -o MethylDackel/{wildcards.sample} {params.MethylDackelOptions} $mi -@ {threads} {params.genome} {input[0]} 1>{log.out} 2>{log.err}
            """
else:
    rule methyl_extract:
        input:
            "bwameth/{sample}.markdup.bam",
            "bwameth/{sample}.markdup.bam.bai"
        output:
            "MethylDackel/{sample}_CpG.bedGraph"
        params:
            genome=genome_fasta,
            MethylDackelOptions=MethylDackelOptions
        log:
            err="MethylDackel/logs/{sample}.methyl_extract.err",
            out="MethylDackel/logs/{sample}.methyl_extract.out"
        threads: 10
        conda: CONDA_WGBS_ENV
        shell: """
            MethylDackel extract -o MethylDackel/{wildcards.sample} {params.MethylDackelOptions} -@ {threads} {params.genome} {input[0]} 1>{log.out} 2>{log.err}
            """


rule prepForMetilene:
    input:
        bedGraphs=expand("MethylDackel/{sample}_CpG.bedGraph", sample=samples)
    output:
        MetileneIN='{}/metilene.IN.txt'.format(get_outdir("metilene", minCoverage))
    params:
        sampleSheet=sampleSheet,
        groups=metileneGroups,
        minCoverage=minCoverage,
        blacklist=blacklist
    log:
        err='{}/logs/prep_for_stats.err'.format(get_outdir("metilene", minCoverage)),
    threads: 10
    conda: CONDA_WGBS_ENV
    script: "../rscripts/WGBS_mergeStats.R"


rule DSS:
    input:
        bedGraphs=expand("MethylDackel/{sample}_CpG.bedGraph", sample=samples)
    output:
        '{}/Stats_report.html'.format(get_outdir("DSS", minCoverage))
    params:
        blacklist=blacklist,
        odir=get_outdir("DSS", minCoverage),
        sampleSheet=sampleSheet,
        groups=metileneGroups,
        maxDist=maxDist,
        minCpGs=minCpGs,
        minMethDiff=minMethDiff,
        minCoverage=minCoverage,
        FDR=FDR
    threads: 10
    benchmark: '{}/.benchmark/DSS.benchmark'.format(get_outdir("DSS", minCoverage))
    conda: CONDA_WGBS_ENV
    script: "../rscripts/WGBS_DSS.Rmd"


rule dmrseq:
    input:
        bedGraphs=expand("MethylDackel/{sample}_CpG.bedGraph", sample=samples)
    output:
        '{}/Stats_report.html'.format(get_outdir("dmrseq", minCoverage))
    params:
        blacklist=blacklist,
        odir=get_outdir("dmrseq", minCoverage),
        sampleSheet=sampleSheet,
        groups=metileneGroups,
        maxDist=maxDist,
        minCpGs=minCpGs,
        minMethDiff=minMethDiff,
        minCoverage=minCoverage,
        FDR=FDR
    threads: 10
    benchmark: '{}/.benchmark/dmrseq.benchmark'.format(get_outdir("dmrseq", minCoverage))
    conda: CONDA_WGBS_ENV
    script: "../rscripts/WGBS_dmrseq.Rmd"


# metileneGroups is provided by the calling snakeFile
# These are NOT filtered
rule run_metilene:
    input:
        MetIN='{}/metilene.IN.txt'.format(get_outdir("metilene", minCoverage))
    output:
        MetBed='{}/DMRs.txt'.format(get_outdir("metilene", minCoverage))
    params:
        groups=metileneGroups,
        maxDist=maxDist,
        minCpGs=minCpGs,
        minMethDiff=minMethDiff,
        FDR=FDR
    log:
        err="{}/logs/run_metilene.err".format(get_outdir("metilene", minCoverage))
    threads: 10
    benchmark: '{}/.benchmark/run_metilene.benchmark'.format(get_outdir("metilene", minCoverage))
    conda: CONDA_WGBS_ENV
    shell: """
        echo -e "chrom\tstart\tend\tq-value\tmean methylation difference\tnCpGs\tp (MWU)\tp (2D KS)\tmean_{params.groups[1]}\tmean_{params.groups[0]}" > {output}
        metilene --groupA {params.groups[1]} \
                 --groupB {params.groups[0]} \
                 --maxdist {params.maxDist} \
                 --mincpgs {params.minCpGs} \
                 --minMethDiff {params.minMethDiff} \
                 --threads {threads} \
                 {input.MetIN} 2>{log.err} \
            | sort -k 1,1 -k2,2n >> {output.MetBed}
        """


# Annotates the metilene DMRs and produces QC plots
rule metileneReport:
    input:
        '{}/DMRs.txt'.format(get_outdir("metilene", minCoverage)),
    output:
        HTML='{}/Stats_report.html'.format(get_outdir("metilene", minCoverage))
    params:
        genes_gtf=genes_gtf,
        outdir=get_outdir("metilene", minCoverage),
        sampleSheet=sampleSheet,
        minMethDiff=minMethDiff,
        FDR=FDR
    threads: 1
    benchmark: '{}/.benchmark/metileneReport.benchmark'.format(get_outdir("metilene", minCoverage))
    conda: CONDA_WGBS_ENV
    script: "../rscripts/WGBS_metileneQC.Rmd"


rule bedGraphToBigWig:
    input: 
        "MethylDackel/{sample}_CpG.bedGraph",
        genome_index
    output:
        "MethylDackel/{sample}_CpG.methylation.bw",
        "MethylDackel/{sample}_CpG.coverage.bw"
    log:
        err='MethylDackel/logs/{sample}_bedGraphToBigWig.stderr'
    threads: 1
    conda: CONDA_SHARED_ENV
    shell: os.path.join(workflow_tools, "bedGraphToBigwig") + " {input[0]} {input[1]} {output[0]} {output[1]} 2> {log.err}"
