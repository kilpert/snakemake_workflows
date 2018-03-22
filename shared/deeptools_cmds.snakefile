### functions shared across workflows ##########################################
################################################################################
import os

## bamcompare
def bamcompare_log2_cmd():
    return((deepTools_path+"bamCompare " +
        "-b1 {input.chip_bam} " +
        "-b2 {input.control_bam} " +
        "-o {output} " +
        "--operation log2 " +
        "--scaleFactorsMethod readCount " +
        "{params.ignoreForNorm} " +
        "--binSize {params.bw_binsize} " +
        "-p {threads} " +
        "{params.read_extension} " +
        "{params.blacklist} " +
        "&> {log}"))

# bamcompare subtract
def bamcompare_subtract_cmd():
    return((deepTools_path+"bamCompare " +
            "-b1 {input.chip_bam} " +
            "-b2 {input.control_bam} " +
            "-o {output} " +
            "--operation subtract " +
            "--scaleFactorsMethod readCount " +
            "--normalizeUsing RPGC --effectiveGenomeSize {params.genome_size} " +
            "{params.ignoreForNorm} " +
            "--binSize {params.bw_binsize} " +
            "-p {threads} " +
            "{params.read_extension} " +
            "{params.blacklist} " +
            "&> {log}"))
# bamCoverage RAW
def bamcov_raw_cmd():
    return((deepTools_path+"bamCoverage " +
            "-b {input.bam} " +
            "-o {output} " +
            "--binSize {params.bw_binsize} " +
            "-p {threads}" 
            "&> {log}"))

# bamCoverage CHIP
def bamcov_cmd():
    return(( deepTools_path+"bamCoverage "+
             "-b {input.bam} " +
             "-o {output} " +
             "--binSize {params.bw_binsize} " +
             "-p {threads} " +
             "--normalizeUsing RPGC --effectiveGenomeSize {params.genome_size} " +
             "{params.ignoreForNorm} " +
             "{params.read_extension} " +
             "&> {log}"))

## bamCoverage RNAseq
def bamcov_rpkm_cmd():
    return( (deepTools_path+"bamCoverage "
            "-b {input.bam} "
            "-o {output} "
            "--binSize {params.bw_binsize} "
            "-p {threads} "
            " --normalizeUsing RPKM "
            "&> {log}") )

## computeGC bias (DNA)
def gcbias_cmd(fragment_length):
            return(
                (deepTools_path+"computeGCBias " +
                "-b {input.bam} " +
                "--biasPlot {output.png} " +
                "--GCbiasFrequenciesFile {output.tsv} " +
                "--effectiveGenomeSize {params.genome_size} " +
                "--genome {params.genome_2bit} " +
                "--fragmentLength "+str(fragment_length)+" " +
                "--sampleSize 10000000 " # very long runtime with default sample size
                "{params.blacklist} " +
                "-p {threads} " +
                "&> {log}")
                )

# plot Enrichment (RNAseq)
def plotEnrich_cmd():
    return( (deepTools_path+"plotEnrichment " +
        "-p {threads} " +
        "-b {input.bam} " +
        "--BED {input.gtf} {input.gtf2} " +
        "--plotFile {output.png} " +
        "--labels {params.labels} " +
        "--plotTitle 'Fraction of reads in regions' " +
        "--outRawCounts {output.tsv} " +
        "--variableScales " +
        "&> {log}") )

# plot Enrichment (ChIPSeq)
def plotEnrich_chip_cmd():
    return((deepTools_path+"plotEnrichment " +
        "-b {input.bams} " +
        "--BED {params.genes_gtf} " +
        "--plotFile {output.png} " +
        "--labels {params.labels} " +
        "--plotTitle 'Sigal enrichment (fraction of reads) without duplicates' " +
        "--outRawCounts {output.tsv} " +
        "--variableScales " +
        "{params.blacklist} " +
        "-p {threads} " +
        "{params.read_extension} " +
        "--ignoreDuplicates " +
        "&> {log}"))

#plot fingerprint (ChIP-seq)
def plotFingerprint_cmd():
    return((deepTools_path+"plotFingerprint " +
            "-b {input.bams} " +
            "--labels {params.labels} " +
            "--plotTitle 'Cumulative read counts per bin without duplicates' " +
            "--ignoreDuplicates " +
            "--outQualityMetrics {output.metrics} " +
            "-p {threads} " +
            "{params.blacklist} " +
            "{params.png} " +
            "{params.read_extension} " +
            "{params.jsd} " +
            "&> {log}"))


# multiBAMsum ChIP
def multiBamSummary_cmd():
    return( (deepTools_path+"multiBamSummary bins " +
                    "-b {input.bams} " +
                    "-o {output} " +
                    "--labels {params.labels} " +
                    "--binSize 1000 " +
                    "{params.blacklist} " +
                    "-p {threads} " +
                    "{params.read_extension} " +
                    "&> {log}") )

# multiBWsum RNA
def multiBWsum_bed_cmd():
    return( (deepTools_path+"multiBigwigSummary BED-file " +
                "--BED {input.bed} " +
                "-b {input.bw} " +
                "-o {output} " +
                "--labels {params.labels} " +
                "--binSize 1000 " +
                "-p {threads} " +
                "&> {log} "))

## plot Corr (both)
def plotCorr_cmd(what):
    return( (deepTools_path+"plotCorrelation " +
                "-in {input} " +
                "-o {output.heatpng} " +
                "--corMethod pearson " +
                "--whatToPlot heatmap " +
                "--skipZeros " +
                "--plotTitle 'Pearson correlation of "+what+" coverage' " +
                "--outFileCorMatrix {output.tsv} " +
                "--colorMap coolwarm " +
                "--plotNumbers " +
                "&> {log}") )

#                "&> {log} && " +
#                deepTools_path+"plotCorrelation " +
#                "-in {input} " +
#                "-o {output.scatterpng} " +
#                "--corMethod pearson " +
#                "--whatToPlot scatterplot " +
#                "--plotTitle 'Pearson correlation of "+what+" coverage' " +
#                "&>> {log}") )


## plot Corr Spearman (both)
def plotCorrSP_cmd(what):
    return( (deepTools_path+"plotCorrelation " +
        "-in {input} " +
        "-o {output.heatpng} " +
        "--corMethod spearman " +
        "--whatToPlot heatmap " +
        "--skipZeros " +
        "--plotTitle 'Spearman correlation of "+what+" coverage' " +
        "--outFileCorMatrix {output.tsv} " +
        "--colorMap coolwarm " +
        "--plotNumbers " +
        "&> {log}"))

#        "&> {log} && " +
#        deepTools_path+"plotCorrelation " +
#        "-in {input} " +
#        "-o {output.scatterpng} " +
#        "--corMethod spearman " +
#        "--whatToPlot scatterplot " +
#        "--plotTitle 'Spearman correlation of "+what+" coverage' " +
#        "&>> {log}"))

# plot PCA (both)
def plotPCA_cmd(what):
    return( (deepTools_path+"plotPCA " +
            "-in {input} " +
            "-o {output} " +
            "-T 'PCA of "+what+" coverage' " +
            "&> {log}") )

# plot Coverage
def plotCoverage_cmd():
    return( (deepTools_path+"plotCoverage " +
                "-b {input.bams} " +
                "-o {output} " +
                "--labels {params.labels} " +
                "--plotTitle 'Genome fragment coverage without duplicates' " +
                "-p {threads} " +
                "{params.read_extension} " +
                "--ignoreDuplicates " +
                "&> {log}") )

#EstimateReadFiltering
def estimateReadFiltering_cmd():
   return( (deepTools_path+"estimateReadFiltering "+
               "-b {input.bam} "+
               "-o {output}") )

#bamPEFragmentSize
def bamPEFragmentSize_cmd():
    return( (deepTools_path+"bamPEFragmentSize " +
             "--bamfiles {input.bams} " +
             "--table {output} " + 
             "-p {threads} " +
             "&> {log}") )
