def downloadFile(url, output):
    import urllib.request
    import gzip
    import bz2
    import os.path

    if os.path.exists(url):
        url = "file://{}".format(urllib.request.pathname2url(url))

    f = urllib.request.urlopen(url)
    content = f.read()
    f.close()

    of = open(output[0], "wb")

    # Sniff the file format and decompress as needed
    first3 = bytes(content[:3])
    if first3 == b"\x1f\x8b\x08":
        of.write(gzip.decompress(content))
    elif first3 == b"\x42\x5a\x68":
        of.write(bz2.decompress(content))
    else:
        of.write(content)
    of.close()


# Default memory allocation: 20G
rule createGenomeFasta:
    output: genome_fasta
    params:
        url = genomeURL
    run:
        downloadFile(params.url, output)


# Default memory allocation: 1G
rule fastaIndex:
    input: genome_fasta
    output: genome_index
    log: "logs/fastaIndex.log"
    conda: CONDA_SHARED_ENV
    shell: """
        samtools faidx {input} 2> {log}
        """

# Default memory allocation: 4G
rule fastaDict:
    input: genome_fasta
    output: genome_dict
    log: "logs/fastaDict.log"
    conda: CONDA_SHARED_ENV
    shell: """
        samtools dict -o {output} {input} 2> {log}
        """

if rmsk_file:
    rule fetchRMSK:
        output: rmsk_file
        params:
            url = rmskURL
        run:
            downloadFile(params.url, output)

# Default memory allocation: 8G
rule make2bit:
    input: genome_fasta
    output: genome_2bit
    log: "logs/make2bit.log"
    conda: CONDA_CREATE_INDEX_ENV
    shell: """
        faToTwoBit {input} {output} 2> {log}
        """


# This is the same as createGenomeFasta, we could decrease this to an external script
# Default memory allocation: 20G
rule downloadGTF:
    output: genes_gtf
    params:
        url = gtfURL
    run:
        downloadFile(params.url, output)


# Default memory allocation: 1G
rule gtf2BED:
    input: genes_gtf
    output: genes_bed
    log: "logs/gtf2BED.log"
    conda: CONDA_CREATE_INDEX_ENV
    shell: """
        awk '{{if ($3 != "gene") print $0;}}' {input} \
            | grep -v "^#" \
            | gtfToGenePred /dev/stdin /dev/stdout \
            | genePredToBed stdin {output} 2> {log}
        """

# Default memory allocation: 1G
# As a side effect, this checks the GTF and fasta file for chromosome name consistency (it will pass if at least 1 chromosome name is shared)
rule extendGenicRegions:
    input: genes_gtf, genome_index
    output: extended_coding_regions_gtf
    run:
        import sys
        import os

        faiChroms = set()
        for line in open(input[1]):
            cols = line.strip().split()
            faiChroms.add(cols[0])

        gtfChroms = set()
        o = open(output[0], "w")
        for line in open(input[0]):
            if line.startswith("#"):
                continue
            cols = line.strip().split("\t")
            gtfChroms.add(cols[0])
            if cols[2] == "gene" or cols[2] == "transcript":
                cols[3] = str(max(1, int(cols[3]) - 500))
                cols[4] = str(int(cols[4]) + 500)
            o.write("\t".join(cols))
            o.write("\n")
        o.close()

        # Ensure there is at least one shared chromosome name between the annotation and fasta file
        try:
            assert len(faiChroms.intersection(gtfChroms)) >= 1
        except:
            os.remove(output[0])
            sys.exit("There are no chromosomes/contigs shared between the fasta and GTF file you have selected!\n")


# Default memory allocation: 20G
rule bowtie2Index:
    input: genome_fasta
    output: os.path.join(outdir, "BowtieIndex/genome.rev.2.bt2")
    log: "logs/bowtie2Index.log"
    params:
      basedir = os.path.join(outdir, "BowtieIndex")
    conda: CONDA_CREATE_INDEX_ENV
    threads: 10
    shell: """
        ln -s {input} {params.basedir}/genome.fa
        bowtie2-build -t {threads} {params.basedir}/genome.fa {params.basedir}/genome
        2> {log}
        """

# Default memory allocation: 20G
rule hisat2Index:
    input: genome_fasta
    output: os.path.join(outdir, "HISAT2Index/genome.6.ht2")
    log: "logs/hisat2Index.log"
    params:
      basedir = os.path.join(outdir, "HISAT2Index")
    threads: 10
    conda: CONDA_CREATE_INDEX_ENV
    shell: """
        ln -s {input} {params.basedir}/genome.fa
        hisat2-build -q -p {threads} {params.basedir}/genome.fa {params.basedir}/genome
        2> {log}
        """


# Default memory allocation: 1G
rule makeKnownSpliceSites:
    input: genes_gtf
    output: known_splicesites
    log: "logs/makeKnownSpliceSites.log"
    conda: CONDA_CREATE_INDEX_ENV
    threads: 10
    shell: """
        hisat2_extract_splice_sites.py {input} > {output} 2> {log}
        """


# Default memory allocation: 80G
rule starIndex:
    input: genome_fasta
    output: os.path.join(outdir, "STARIndex/SAindex")
    log: "logs/starIndex.log"
    params:
      basedir = os.path.join(outdir, "STARIndex")
    conda: CONDA_CREATE_INDEX_ENV
    threads: 10
    shell: """
        STAR --runThreadN {threads} --runMode genomeGenerate --genomeDir {params.basedir} --genomeFastaFiles {input} 2> {log}
        rm Log.out
        """


# Default memory allocation: 8G
rule bwaIndex:
    input: genome_fasta
    output: os.path.join(outdir, "BWAIndex/genome.fa.sa")
    log: "logs/bwaIndex.log"
    params:
      genome = os.path.join(outdir, "BWAIndex", "genome.fa")
    conda: CONDA_CREATE_INDEX_ENV
    shell: """
        ln -s {input} {params.genome}
        bwa index {params.genome} 2> {log}
        """


# Default memory allocation: 8G
rule bwamethIndex:
    input: genome_fasta
    output: os.path.join(outdir, "BWAmethIndex/genome.fa.bwameth.c2t.sa")
    log: "logs/bwamethIndex.log"
    params:
      genome = os.path.join(outdir, "BWAmethIndex", "genome.fa")
    conda: CONDA_CREATE_INDEX_ENV
    shell: """
        ln -s {input[0]} {params.genome}
        bwameth.py index {params.genome} 2> {log}
        """


# Default memory allocation: 1G
rule copyBlacklist:
    output: os.path.join(outdir, "annotation/blacklist.bed")
    params:
        url = blacklist
    run:
        downloadFile(params.url, output)


# Default memory allocation: 1G
rule computeEffectiveGenomeSize:
    input: genome_fasta
    output: os.path.join(outdir, "genome_fasta", "effectiveSize")
    log: "logs/computeEffectiveGenomeSize.log"
    conda: CONDA_SHARED_ENV
    shell: """
        seqtk comp {input} | awk '{{tot += $3 + $4 + $5 + $6}}END{{print tot}}' > {output} 2> {log}
        """
