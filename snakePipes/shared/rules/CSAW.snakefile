sample_name = os.path.splitext(os.path.basename(sampleSheet))[0]
change_direction = ["UP", "DOWN", "MIXED"]

def getInputPeaks(peakCaller, chip_samples, genrichDict):
    if peakCaller == "MACS2":
        if pipeline in 'ATAC-seq':
            return expand("MACS2/{chip_sample}.filtered.short.BAM_peaks.xls", chip_sample = chip_samples)
        else:
            return expand("MACS2/{chip_sample}.filtered.BAM_peaks.xls", chip_sample = chip_samples)
    elif peakCaller == "HMMRATAC":
        return expand("HMMRATAC/{chip_sample}_peaks.gappedPeak", chip_sample = chip_samples)
    else:
        return expand("Genrich/{genrichGroup}.narrowPeak", genrichGroup = genrichDict.keys())


## CSAW for differential binding / allele-specific binding analysis
rule CSAW:
    input:
        peaks = getInputPeaks(peakCaller, chip_samples, genrichDict),
        sampleSheet = sampleSheet,
        insert_size_metrics ="deepTools_qc/bamPEFragmentSize/fragmentSize.metric.tsv" if pairedEnd else []
    output:
        "CSAW_{}_{}/CSAW.session_info.txt".format(peakCaller, sample_name),
        "CSAW_{}_{}/DiffBinding_analysis.Rdata".format(peakCaller, sample_name),
        expand("CSAW_{}_{}".format(peakCaller, sample_name) + "/Filtered.results.{change_dir}.bed", change_dir=change_direction)
    benchmark:
        "CSAW_{}_{}/.benchmark/CSAW.benchmark".format(peakCaller, sample_name)
    params:
        outdir=os.path.join(outdir, "CSAW_{}_{}".format(peakCaller, sample_name)),
        peakCaller=peakCaller,
        fdr = fdr,
        absBestLFC=absBestLFC,
        pairedEnd = pairedEnd,
        fragmentLength = fragmentLength,
        windowSize = windowSize,
        importfunc = os.path.join("shared", "rscripts", "DB_functions.R"),
        allele_info = allele_info,
        yaml_path=lambda wildcards: samples_config if pipeline in 'chip-seq' else "",
        insert_size_metrics=os.path.join(outdir,"deepTools_qc/bamPEFragmentSize/fragmentSize.metric.tsv") if pairedEnd else [],
        pipeline = pipeline
    log:
        out = os.path.join(outdir, "CSAW_{}_{}/logs/CSAW.out".format(peakCaller, sample_name)),
        err = os.path.join(outdir, "CSAW_{}_{}/logs/CSAW.err".format(peakCaller, sample_name))
    conda: CONDA_ATAC_ENV
    script: "../rscripts/CSAW.R"


if allele_info == 'FALSE':
    if pipeline in 'chip-seq':
        rule calc_matrix_log2r_CSAW:
            input:
                csaw_in = "CSAW_{}_{}/CSAW.session_info.txt".format(peakCaller, sample_name),
                bigwigs = expand("deepTools_ChIP/bamCompare/{chip_sample}.filtered.log2ratio.over_{control_name}.bw", zip, chip_sample=filtered_dict.keys(), control_name=filtered_dict.values()),
                sampleSheet = sampleSheet
            output:
                matrix = touch("CSAW_{}_{}".format(peakCaller, sample_name)+"/CSAW.{change_dir}.log2r.matrix")
            params:
                bed_in = "CSAW_{}_{}".format(peakCaller, sample_name)+"/Filtered.results.{change_dir}.bed"
            log:
                out = os.path.join(outdir, "CSAW_{}_{}".format(peakCaller, sample_name) + "/logs/deeptools_matrix.log2r.{change_dir}.out"),
                err = os.path.join(outdir, "CSAW_{}_{}".format(peakCaller, sample_name) + "/logs/deeptools_matrix.log2r.{change_dir}.err")
            threads: 8
            conda: CONDA_SHARED_ENV
            shell: """
                touch {log.out}
                touch {log.err}
                if [[ -s {params.bed_in} ]]; then
                    computeMatrix scale-regions -S {input.bigwigs} -R {params.bed_in} -m 1000 -b 200 -a 200 -o {output.matrix} -p {threads} >{log.out} 2>{log.err}
                fi
                """


        rule plot_heatmap_log2r_CSAW:
            input:
                matrix = "CSAW_{}_{}".format(peakCaller, sample_name) + "/CSAW.{change_dir}.log2r.matrix"
            output:
                image = touch("CSAW_{}_{}".format(peakCaller, sample_name) + "/CSAW.{change_dir}.log2r.heatmap.png"),
                sorted_regions = touch("CSAW_{}_{}".format(peakCaller, sample_name) + "/CSAW.{change_dir}.log2r.sortedRegions.bed")
            params:
                smpl_label=' '.join(filtered_dict.keys())
            log:
                out = os.path.join(outdir, "CSAW_{}_{}".format(peakCaller, sample_name) + "/logs/deeptools_heatmap.log2r.{change_dir}.out"),
                err = os.path.join(outdir, "CSAW_{}_{}".format(peakCaller, sample_name) + "/logs/deeptools_heatmap.log2r.{change_dir}.err")
            conda: CONDA_SHARED_ENV
            shell: """
                touch {log.out}
                touch {log.err}
                if [[ -s {input.matrix} ]]; then
                    plotHeatmap --matrixFile {input.matrix} \
                                --outFileSortedRegions {output.sorted_regions} \
                                --outFileName {output.image} \
                                --startLabel Start --endLabel End \
                                --legendLocation lower-center \
                                -x 'Scaled peak length' --labelRotation 90 \
                                --samplesLabel {params.smpl_label} --colorMap "coolwarm" > {log.out} 2> {log.err}
                fi
                """


    rule calc_matrix_cov_CSAW:
        input:
            csaw_in = "CSAW_{}_{}/CSAW.session_info.txt".format(peakCaller, sample_name),
            bigwigs = expand("bamCoverage/{chip_sample}.filtered.seq_depth_norm.bw", chip_sample=filtered_dict.keys()),
            sampleSheet = sampleSheet
        output:
            matrix = touch("CSAW_{}_{}".format(peakCaller, sample_name) + "/CSAW.{change_dir}.cov.matrix")
        params:
            bed_in = "CSAW_{}_{}".format(peakCaller, sample_name) + "/Filtered.results.{change_dir}.bed"
        log:
            out = os.path.join(outdir, "CSAW_{}_{}".format(peakCaller, sample_name) + "/logs/deeptools_matrix.cov.{change_dir}.out"),
            err = os.path.join(outdir, "CSAW_{}_{}".format(peakCaller, sample_name) + "/logs/deeptools_matrix.cov.{change_dir}.err")
        threads: 8
        conda: CONDA_SHARED_ENV
        shell: """
            touch {log.out}
            touch {log.err}
            if [[ -s {params.bed_in} ]]; then
                computeMatrix scale-regions -S {input.bigwigs} -R {params.bed_in} \
                -m 1000 -b 200 -a 200 -o {output.matrix} -p {threads} >{log.out} 2>{log.err}
            fi
            """


    rule plot_heatmap_cov_CSAW:
        input:
            matrix = "CSAW_{}_{}".format(peakCaller, sample_name) + "/CSAW.{change_dir}.cov.matrix"
        output:
            image = touch("CSAW_{}_{}".format(peakCaller, sample_name) + "/CSAW.{change_dir}.cov.heatmap.png"),
            sorted_regions = touch("CSAW_{}_{}".format(peakCaller, sample_name) + "/CSAW.{change_dir}.cov.sortedRegions.bed")
        params:
            smpl_label=' '.join(filtered_dict.keys())
        log:
            out = os.path.join(outdir,"CSAW_{}_{}".format(peakCaller, sample_name) + "/logs/deeptools_heatmap.cov.{change_dir}.out"),
            err = os.path.join(outdir,"CSAW_{}_{}".format(peakCaller, sample_name) + "/logs/deeptools_heatmap.cov.{change_dir}.err")
        conda: CONDA_SHARED_ENV
        shell: """
            touch {log.out}
            touch {log.err}
            if [[ -s {input.matrix} ]]; then
                plotHeatmap --matrixFile {input.matrix} \
                            --outFileSortedRegions {output.sorted_regions} \
                            --outFileName {output.image} --startLabel Start \
                            --endLabel End --legendLocation lower-center \
                            -x 'Scaled peak length' --labelRotation 90 \
                            --samplesLabel {params.smpl_label} --colorMap "coolwarm" >{log.out} 2>{log.err}
            fi
            """


    rule CSAW_report:
        input:
            csaw_in = "CSAW_{}_{}/CSAW.session_info.txt".format(peakCaller, sample_name),
            heatmap_in=lambda wildcards: expand("CSAW_{}_{}".format(peakCaller, sample_name) +\
             "/CSAW.{change_dir}.cov.heatmap.png", change_dir=['UP','DOWN']) if pipeline in 'ATAC-seq' \
             else expand("CSAW_{}_{}".format(peakCaller, sample_name) + "/CSAW.{change_dir}.cov.heatmap.png", change_dir=['UP','DOWN']) +\
              expand("CSAW_{}_{}".format(peakCaller, sample_name) + "/CSAW.{change_dir}.log2r.heatmap.png", change_dir=['UP', 'DOWN'])
        output:
            outfile="CSAW_{}_{}/CSAW.Stats_report.html".format(peakCaller, sample_name)
        params:
            pipeline=pipeline,
            fdr=fdr,
            lfc=absBestLFC,
            outdir=os.path.join(outdir, "CSAW_{}_{}".format(peakCaller, sample_name)),
            sampleSheet=sampleSheet
        log:
           out = os.path.join(outdir, "CSAW_{}_{}/logs/report.out".format(peakCaller, sample_name)),
           err = os.path.join(outdir, "CSAW_{}_{}/logs/report.err".format(peakCaller, sample_name))
        conda: CONDA_ATAC_ENV
        script: "../rscripts/CSAW_report.Rmd"
