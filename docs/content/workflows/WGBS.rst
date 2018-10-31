.. _WGBS:

WGBS
====

Input requirements
------------------

This pipeline requires paired-end reads fastq files and a genome alias, for which bwa-meth index has been built.
Optional inputs include bed files with genomic intervals of interest, used to aggregate single CpG values over; a sample sheet with grouping information to use in differential methylation analysis; a blacklist bed file with genomic positions corresponding to known snps to mask single CpG methylation values.

It is possible to use pipeline-compatible bam files as input. For that, the user has to use the --fromBam flag and provide the bam file extention if not matched by the default. Note that this will disable calculating conversion rate as this steps requires fastq.gz input.
This is an experimental feature.


What it does
------------

Optionally trimmed reads are mapped to reference genome using a bisulfite-specific aligner (bwa-meth).
Quality metrics are collected and synthesized in a QC report, including bisulfite conversion rate, mapping rate, percentage CpGs covered a least 10x, methylation bias.

There are two flags that allow skipping certain QC metric calculation, i.e. skipDOC and skipGCbias. These deactivate the GATK-dependent calculation of depth of coverage and the deepTools-dependent calculation of GC bias,respectively, e.g. in case these metrics are known from another source.

Methylation ratios are extracted (MethylDackel) for CpG positions in the reference genome with a minimum coverage (10x) and low snp allelic frequency (<0.25 illegitimate bases).
If sample sheet is provided, logit-transformed beta values for CpG positions are tested for differential methylation using limma.
Metilene is called to detect de novo DMRs. In addition to the nonparametric statistics output by metilene, limma-derived statistics are recalculated for DMRs, which are further annotated with nearest gene information.
If bed file(s) with genomic intervals of interest are provided, methylation ratios are aggregated over those and limma is used on logit-transformed methylation ratios to test for differential methylation.


.. image:: ../images/WGBS_pipeline.png

Workflow configuration file
---------------------------

.. code:: bash

    $ cat snakePipes/workflows/WGBS/defaults.yaml

.. parsed-literal::

	################################################################################
	# This file is the default configuration of the WGBS workflow!
	#
	# In order to adjust some parameters, please either use the wrapper script
	# (eg. /path/to/snakemake_workflows/workflows/WGBS/WGBS)
	# or save a copy of this file, modify necessary parameters and then provide
	# this file to the wrapper or snakemake via '--configfile' option
	# (see below how to call the snakefile directly)
	#
	# Own parameters will be loaded during snakefile executiuon as well and hence
	# can be used in new/extended snakemake rules!
	################################################################################
	## General/Snakemake parameters, only used/set by wrapper or in Snakemake cmdl, but not in Snakefile
	outdir:
	configfile:
	cluster_configfile:
	local: False
	max_jobs: 12
	nthreads: 8
	## directory with fastq or bam files
	indir:
	## directory with fastqc files for auto quality trimming
	fqcin:
	## Genome information
	genome:
	convrefpath:
	convRef: False
	###list of bed files to process
	intList: []
	###SNP black list (bed file)
	blackList:
	###sample Info
	sampleInfo:
	###inclusion bounds for methylation extraction
	mbias_ignore: auto
	## FASTQ file extension (default: ".fastq.gz")
	ext: '.fastq.gz'
	## paired-end read name extension (default: ['_R1', "_R2"])
	reads: [_R1, _R2]
	## Number of reads to downsample from each FASTQ file
	downsample:
	## Options for trimming
	trimReads: 'user'
	adapterSeq: AGATCGGAAGAGC
	nextera: False
	trimThreshold: 10
	trimOtherArgs: ""
	verbose: False
	#### Flag to control the pipeline entry point
	fromBam: False
	bam_ext: '.PCRrm.bam'
	###Flags to control skipping of certain QC calculations
	skipDOC: False
	skipGCbias: False
	################################################################################
	# Call snakemake directly, i.e. without using the wrapper script:
	#
	# Please save a copy of this config yaml file and provide an adjusted config
	# via '--configfile' parameter!
	# example call:
	#
	# snakemake --snakefile /path/to/snakemake_workflows/workflows/WGBS/Snakefile
	#           --configfile /path/to/snakemake_workflows/workflows/WGBS/defaults.yaml
	#           --directory /path/to/outputdir
	#           --cores 32
	################################################################################


Structure of output directory
-----------------------------

The WGBS pipeline invoked with reads as input, providing a sample sheet as well as target intervals, will generate output as follows:

.. code:: bash

    $ tree -d -t -L 2 output_dir/

::

    output_dir
    |-- cluster_logs
    |-- metilene_out_example
    |   `-- logs
    |-- aux_files
    |   `-- logs
    |-- aggregate_stats_limma_example
    |   `-- logs
    |-- singleCpG_stats_limma_example
    |   `-- logs
    |-- QC_metrics
    |   `-- logs
    |-- methXT
    |   `-- logs
    |-- bams
    |   `-- logs
    |-- FASTQ_Cutadapt
    |   `-- logs
    |-- FASTQ_downsampled
    |   `-- logs
    `-- FASTQ

Aggregate stats will be calculated if user provides at least one bed file with genomic intervals of interest. Differential methylation analysis (singleCpG stats) or DMR detection (metilene_out) will only be run if user provides a sample sheet. It is possible to rerun the differential methylation analysis multiple times using different sample sheet files at a time (e.g. to specify different sample subsets or different contrasts). The name of the sample sheet is appended to the respective result folders (in this case: "example").

Detailed description of the output folders and files, in order of creation by the worflow:


- FASTQ: contains symlinks to original fastq.gz files

- FASTQ_downsampled: contains read files downsampled to 5mln reads. These are used to calculate conversion rate which would otherwise take a very long time.

- bams: contains bam files obtained through read alignment with bwa-meth and the PCR duplicate removal with sambamba, as well as matching bam index files.

- methXT: contains counts of methylated and unmethylated reads per CpG position in the genome in the bedGraph format as output by methylDackel using filtering thresholds (*_CpG.bedGraph files). Contains also the 'filtered' *.CpG.filt2.bed files, after applying redundant coverage filtering or masking CpG positions intersecting a bed file with SNP positions if provided by the user. The latter are used in the downstream statistical analysis.

- QC_metrics: contains output files from conversion rate, flagstat, depth of coverage, GCbias and methylation bias calculations. The QC report in pdf format collecting those metrics in tabular form is also found in this folder.

- singleCpG_stats_limma_*suffix: contains output files from the single CpG differential methylation analysis module. A PCA plot for all samples as well as density and violin plots per sample group are output, provided any sites pass cross-replicate filtering. A t-test on logit-transformed group means is output to GroupMean.ttest.txt. If any differentially methylated sites at 5%FDR are detected, these are output to  limdat.LG.CC.tT.FDR5.txt with corresponding limma statistics. The table with methylation ratios merged from replicates is saved to limdat.LG.RData. A table formatted as metilene input is written to metilene.IN.txt.

- aggregate_stats_limma_*suffix: contains output files from the user-provided target interval differential methylation analysis module. A table with methylation ratios for single CpG positions output by the single CpG stat module is intersected with the bed file provided by the user. Single CpG methylation ratios are averaged over the intervals so that each replicate obtains one aggregate (mean) methylation value per genomic interval provided by the user, as long as at least 20% of the CpGs in that interval were extracted and passed filtering. The new table of methylation ratios per genomic interval is subjected to an analysis analogous to the singleCpG stats module, so that a PCA plot for all samples is output, alongside a table of differentially methylated intervals (*tT.FDR5.txt) and an R object storing the original data (*.aggCpG.RData). Files are prefixed with a prefix extracted from the bed file name provided by the user.

- aux_files: contains a number of intermediate auxiliary files e.g. the index of genomic CpGs as well as bed files containing CpG annotation of interval files provided by the user.

- metilene_out_*suffix: contains output files from metilene analysis. The original metilene output is stored in singleCpG.metilene.bed. Genomic intervals output by metilene are processed similarly as the genomic intervals provided by the user with the aggregate stats limma module. A PCA plot as well as violin and density plots are output. A table of differentially methylated intervals is written to singleCpG.metilene.CGI.limdat.CC.tT.FDR5.txt and the methylation table is stored in singleCpG.metilene.limma.RData. The differentially methylated regions (at FDR <5%) are further annotated with their closest gene using annotation as defined by the genes_bed entry of the organism dictionary. Gene IDs and gene symbols are added with biomaRt and the final annotated table is written to metilene.limma.annotated.txt. The table is split into regions with upregulated (metilene.limma.annotated.UP.txt)  and downregulated (metilene.limma.annotated.DOWN.txt) methylation.

- cluster_logs: contains stdout and sterr collected from the cluster controller per executed job.


Example output plots
--------------------

Using data from Habibi et al., Cell Stem Cell 2013 corresponding to mouse chr6:4000000-6000000, following plots could be obtained:

.. image:: ../images/limdat.LG.CC.PCA.png

.. image:: ../images/Beta.MeanXgroup.all.violin.png


Command line options
--------------------

.. argparse::
    :func: parse_args
    :filename: ../snakePipes/workflows/WGBS/WGBS
    :prog: WGBS
    :nodefault:
