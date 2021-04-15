import glob
import os
import subprocess
import pandas as pd
## Main variables ##############################################################


# minimum distance to consider between restriction sites. RS that are closer than this
# distance are merged. This value should be similar to the read length
MIN_RS_DISTANCE = 150
# Maximum distance of that a read can be from a restriction site. Reads farther than this distance are discarded.
# This number should be related to the higher end of fragment length distribution.
MAX_RS_DISTANCE = 1000
# this is to identify so called dangling ends. Option are 'AAGCTT' or 'GATC'
#fastq_dir = 'fastq'
#samples = ['SRR2240738', 'SRR2240739', 'SRR2240740']

### Functions ##################################################################
# define matrix format (filename suffix)
matrix_format = matrixFormat

## find out which resolution is it (RF or binsize)
def get_matrixFile_suffix():
    if(RFResolution is True):
        return("rf")
    else:
        bin_size = int(binSize/1000)
        return("bs"+str(bin_size)+"kb")
matrixFile_suffix = get_matrixFile_suffix()

## seq dict for restriction enzymes
seq_dict = {
           'DpnII' : ['GATC', 'GATC'],
           'HindIII' : ['AAGCTT', 'AGCTT'],
           'HinfI' : ['GANTC', 'ANTC'],
           'Arima' : ['"GANTC GATC"', '"ANTC GATC"']
           }

## get sequences for restriction enzymes
def get_restriction_seq(name):
    seq = seq_dict[name][0]
    return(seq)

def get_dangling_seq(name):
    seq = seq_dict[name][1]
    return(seq)

## merge all the HiC matrices and create new file if asked
def merge_inputs():
    if(mergeSamples is True):
        return(["HiC_matrices/all_matrices_merged"+matrix_format #,"HiC_matrices/QCplots/all_matrices_merged_diagnostic_plot.pdf"
               ])
    else:
        return([])

## merge hic Bins if asked and create new files
def get_merged_bins():
    if(nBinsToMerge != 0):
        return(expand("HiC_matrices/{sample}_"+matrixFile_suffix+"_m"+str(nBinsToMerge)+matrix_format, sample=samples))
    else:
        return([])

## get MAD thresholds for the matrix correction
def get_mad_score(madfile):
    with open(madfile) as md:
        lower = 0.0
        for line in md:
            lower = float(line.split()[2])
    upper = -(3*lower)
    cutoff = str(lower) + " " + str(upper)
    return(cutoff)

## get sample grouping information
def get_sampleSheet(sample_sheet):
    sample_dict = dict()
    if sample_sheet:  # Read the sample info and fill in a dictionary
        sample_dict = cf.sampleSheetGroups(sample_sheet)
    else:
        sample_dict['merged'] = []
        for sample in samples:
            sample_dict['merged'].append(sample)

    return sample_dict

## trim
fastq_dir = "FASTQ"
if trim:
    fastq_indir_trim = "FASTQ"
    if trimmer == "trimgalore":
        fastq_dir = "FASTQ_TrimGalore"
    elif trimmer == "cutadapt":
        fastq_dir = "FASTQ_Cutadapt"
    elif trimmer == "fastp":
        fastq_dir = "FASTQ_fastp"

### Initialization #############################################################
infiles = sorted(glob.glob(os.path.join(str(indir or ''), '*'+ext)))
samples = cf.get_sample_names(infiles,ext,reads)
pairedEnd = cf.is_paired(infiles,ext,reads)
del infiles
fromBAM = None

if not samples:
    print("\n  Error! NO samples found in dir "+str(indir or '')+"!!!\n\n")
    exit(1)

if not pairedEnd:
    print("\n  Error! Paired-end samples not detected. "
          "Hi-C workflow requires paired-end samples "+str(indir or '')+"!!!\n\n")
    exit(1)
