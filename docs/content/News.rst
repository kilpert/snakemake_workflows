snakePipes News
===============
snakePipes 2.1.1
----------------
* small bug fix: a typo in atac-seq pipeline

snakePipes 2.1.0
----------------

 * Snakemake version is bumped to 5.13.0
 * Updated docs on running single snakefiles
 * Added user-input target regions and freetext parameters to differential methylation analysis with metilene
 * Added PCA to metilene report in WGBS
 * Added Genrich support for SE data
 * Edited symlinking rules to `ln -s` or python
 * TMPDIR is now passed at rule-level to the shell
 * Added logs in a couple of places
 * Added `--skipBamQC` to WGBS to be included with `--fromBAM` to suppress recalculation of QC metrics on the bam file
 * Added tempDir check to snakePipes info
 * Added `--oldConfig` and `--configMode` options to snakePipes config that allow passing a copy of an existing pre-configured config file instead of passing the single paths. Previous mode can be used with `--configMode manual` (default), the new mode with `--configMode recycle`.
 * Updated histoneHMM version to 1.8. Changed number formatting in histoneHMM output from scientific to general.
 * Small fixes in DESeq2 report for noncoding-RNA-seq, WGBS reports
 * Fixed `--verbose` in WGBS
 * Fixed an important bug in differential binding analysis with CSAW (mismatch between sampleSheet rownames and countdata colnames).


snakePipes 2.0.2
----------------

 * DAG print is now moved to _after_ workflow run execution such that any error messages from e.g. input file evaluation do not interfere with the DAG and are visible to the user.
 * Fixed fastqc for --forBAM .
 * Fixed DESeq2 report failure with just 1 DEG.
 * Updated links to test data and commands on zenodo in the docs.
 * SampleSheet check now explicitly checks for tab-delimited header.
 * Fixed metilene groups, as well methylation density plots in WGBS.

snakePipes 2.0.1
----------------

 * Fixed a bug in `snakePipes config` that caused the `toolsVersion` variable to be removed from `defaults.yaml`. This is likely related to issue #579.

snakePipes 2.0.0
----------------

 * Added a noncoding-RNA-seq workflow and renamed RNA-seq to mRNA-seq for clarity. The noncoding workflow will also quantify protein coding genes, but its primary use is analyzing repeat expression.
 * In order to use the noncoding-RNA-seq workflow organism YAML files must now include a `rmsk_file` entry.
 * Fixed STAR on CIFS mounted VFAT file systems (issue #537).
 * Added mode STARsolo to scRNAseq. This mode is now default.
 * Added log fold change shrinkage with "apeglm" to DESeq2 basic in the mRNAseq workflow. Two versions of results tables (with and without shrinkage) are now written to the DESeq2 output folder.
 * Added Genrich as peakCaller option to ChIPseq and ATACseq.
 * Added HMMRATAC as peakCaller option to ATACseq.
 * ATAC-seq short bam (filtered for short fragments) is now stored in a separate folder.

.. note::
   Please be aware that this version requires regeneration of STAR indices!

snakePipes 1.3.2
----------------

 * Fixed missing multiQC input in allelic RNAseq
 * Added sample check to those workflows that were missing it.

snakePipes 1.3.1
----------------

 * Support for snakeMake 5.7.0

snakePipes 1.3.0
----------------

 * Overhauled WGBS pipeline
 * Standardized options to be camelCase
 * Further standardized options between pipelines
 * UMI handling is now available in most pipelines
 * The ``--fromBAM`` option is now available and documented
 * Users can now change the read number indicator ("_R1" and "_R2" by default) as well as the fastq file extension on the command line.
 * Added the preprocessing pipeline, prevented python packages in users' home directories from inadvertently being used.
 * Added a ``snakePipes config`` command that can be used in lieu of editing defaults.yaml

snakePipes published
--------------------
snakePipes was published: https://www.ncbi.nlm.nih.gov/pubmed/31134269

snakePipes 1.2.3
----------------

 * Updated citation for snakePipes
 * Fixed replicate check for samples with trailing spaces in names
 * Fixed input filtering in CSAW
 * Several allele-specific RNAseq fixes
 * ATACseq peakQC is now run on fragment-size filtered bam
 * Fixed Salmon output (Number of Reads output in "prefix_counts.tsv" files and file naming)
 * Fixed CSAW QC plot error with single end reads
 * Updated histone HMM environment to a working conda version
 * Salmon_wasabi is now a localrule


snakePipes 1.2.2
----------------

 * Fixed a bug in the ATAC-seq environment where GenomeInfoDbData was missing.
 * Also an occasional issue with CSAW


snakePipes 1.2.1
----------------

 * Fixed a typo in ``createIndices``.
 * Implemented complex experimental design in RNAseq (differential gene expression), ChIP/ATACseq (differential binding).
 * Fixed an issue with ggplot2 and log transformation in RNAseq report Rmd.
 * fastqc folder is created and its content will be added to multiqc only if fastqc flag is called.
 * fastqc-trimmed folder is created and its content will be added to multiqc only if both fastqc and trim flags are called.

snakePipes 1.2.0
----------------

 * A number of minor bug fixes across all of the pipelines
 * Updates of all tool versions and switching to R 3.5.1
 * A ``snakePipes flushOrganisms`` option was added to remove the default organism YAML files.
 * Renamed ``--notemp`` to ``--keepTemp``, which should be less confusing

snakePipes 1.1.2
----------------

 * A number of minor bug fixes and enhancements in the HiC and WGBS pipelines
 * The RNA-seq pipeline now uses samtools for sorting. This should avoid issues with STAR running out of memory during the output sorting step.
 * Increased the memory allocation for MACS2 to 8GB and bamPEFragmentSize to 3G
 * Fixed the scRNA-seq pipeline, which seems to have been broken in 1.1.1

snakePipes 1.1.1
----------------

 * Fixed some conda environments so they could all be solved in a reasonable amount of time.
 * Updated some WGBS memory limits

snakePipes 1.1.0
----------------

 * A wide number of bug fixes to scRNA-seq and other pipelines. In particular, many memory limits were updated.
 * An optional email can be sent upon pipeline completion.
 * The RNA-seq pipeline can now produce a fuller report upon completion if you are performing differential expression.
 * Sample merging in HiC works properly.
 * GTF files are now handled more generically, which means that they no longer need to have \_gencode and \_ensembl in their path.
 * WGBS:

   * Merging data from WGBS replicates is now an independent step so that dependent rules don't have to wait for successful completion of single CpG stats but can go ahead instead.
   * Filtering of differential methylation test results is now subject to two user-modifiable parameters minAbsDiff (default 0.2) and FDR (0.02) stored in defaults.yaml.
   * Metilene commandline parameters are now available in defaults.yaml. Defaults are used apart from requesting output intervals with any methylation difference (minMethDiff 0).
   * Additional diagnostic plots are generated - p value distribution before and after BH adjustment as well as a volcano plot.
   * Automatic reports are generated in every folder containing results of statistical analysis (single CpG stats, metilene DMR stats, user interval aggregate stats), as long as sample sheet is provided.
   * R sessionInfo() is now printed at the end of the statistical analysis.

 * scRNAseq:

   * An extention to the pipeline now takes the processed csv file from Results folder as input and runs cell filtering with a range of total transcript thresholds using monocle and subsequently runs clustering, produces tsne visualizations, calculates top 2 and top10 markers per cluster and produces heatmap visualizations for these using monocle/seurat. If the skipRaceID flag is set to False (default), all of the above are also executed using RaceID.
   * Stats reports were implemented for RaceID and Monocle/Seurat so that folders Filtered_cells_RaceID and Filtered_cells_monocle now contain a Stats_report.html.
   * User can select a metric to maximize during cell filtering (cellFilterMetric, default: gene_universe).
   * For calculating median GPC, RaceID counts are multiplied by the TPC threshold applied (similar to 'downscaling' in RaceID2).

 * all sample sheets now need to have a "name" and a "condition" column, that was not consistent before
 * consistent --sampleSheet [FILE] options to invoke differential analysis mode (RNA-seq, ChIP-seq, ATAC-seq), --DE/--DB were dropped

snakePipes 1.0.0 (king cobra) released
--------------------------------------

**9.10.2018**

First stable version of snakePipes has been released with various feature improvements. You can download it `from GitHub <https://github.com/maxplanck-ie/snakepipes/releases/tag/1.0.0>`__

snakePipes preprint released
----------------------------

We relased the preprint of snakePipes describing the implementation and usefullness of this tool in integrative epigenomics analysis. `Read the preprint on bioRxiv <https://www.biorxiv.org/content/early/2018/09/04/407312>`__
