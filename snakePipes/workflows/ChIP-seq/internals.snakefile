import glob
import os
import subprocess
import re
import yaml
import sys


### Functions ##################################################################

def get_control(sample):
    """
    Return control sample name for a given ChIP-seq sample
    Return False if given ChIP-seq sample has no control
    """
    if sample in chip_samples_w_ctrl:
        return chip_dict[sample]['control']
    else:
        return False

def get_control_name(sample):
    """
    Return control sample alias for a given ChIP-seq sample
    Return False if given ChIP-seq sample has no control
    """
    if sample in chip_samples_w_ctrl:
        if 'control' in chip_dict[sample] and chip_dict[sample]['control'] != None:
            return chip_dict[sample]['control']
        else:
            return False
    else:
        return False

def is_broad(sample):
    """
    Return True if given ChIP-seq sample is annotated as sample with
    broad enrichment, else return False
    """
    if sample in chip_dict:
        return chip_dict[sample]['broad']
    else:
        return False


def is_chip(sample):
    """
    Return True if a given sample is a ChIP-seq sample
    Else return False
    """
    return (sample in chip_samples)


### Variable defaults ##########################################################
### Initialization #############################################################

# TODO: catch exception if ChIP-seq samples are not unique
# read ChIP-seq dictionary from config.yaml:
# { ChIP1: { control: Input1, broad: True }, ChIP2: { control: Input2, broad: false }
#config["chip_dict"] = {}

if not os.path.isfile(samples_config):
    print("ERROR: Cannot find samples file ("+samples_config+")")
    exit(1)

if sampleSheet:
    cf.check_sample_info_header(sampleSheet)
    if not cf.check_replicates(sampleSheet):
        print("\nWarning! CSAW cannot be invoked without replicates!\n")
        sys.exit()

chip_dict = {}
with open(samples_config, "r") as f:
    chip_dict_tmp = yaml.load(f, Loader=yaml.FullLoader)
    if "chip_dict" in chip_dict_tmp and chip_dict_tmp["chip_dict"] :
        chip_dict = chip_dict_tmp["chip_dict"]
    else:
        print("\n  Error! Sample config has empty or no 'chip_dict' entry! ("+config["samples_config"]+") !!!\n\n")
        exit(1)
    del chip_dict_tmp

cf.write_configfile(os.path.join("chip_samples.yaml"), chip_dict)

# create unique sets of control samples, ChIP samples with and without control
control_samples = set()
chip_samples_w_ctrl = set()
chip_samples_wo_ctrl = set()
for chip_sample, value in chip_dict.items():
    # set control to False if not specified or set to False
    if 'control' not in chip_dict[chip_sample] or not value['control']:
        chip_dict[chip_sample]['control'] = False
        chip_samples_wo_ctrl.add(chip_sample)
    else:
        control_samples.add(value['control'])
        chip_samples_w_ctrl.add(chip_sample)
    # set broad to False if not specified or set to False
    if 'broad' not in chip_dict[chip_sample] or not value['broad']:
        chip_dict[chip_sample]['broad'] = False

control_samples = list(sorted(control_samples))
# get a list of corresp control_names for chip samples
control_names = []
for chip_sample in chip_samples_w_ctrl:
    control_names.append(get_control_name(chip_sample))

chip_samples_w_ctrl = list(sorted(chip_samples_w_ctrl))
chip_samples_wo_ctrl = list(sorted(chip_samples_wo_ctrl))
chip_samples = sorted(chip_samples_w_ctrl + chip_samples_wo_ctrl)
all_samples = sorted(control_samples + chip_samples)

if not fromBAM:
    if pairedEnd:
        if not os.path.isfile(os.path.join(workingdir, "deepTools_qc/bamPEFragmentSize/fragmentSize.metric.tsv")):
            sys.exit('ERROR: {} is required but not present\n'.format(os.path.join(workingdir, "deepTools_qc/bamPEFragmentSize/fragmentSize.metric.tsv")))

    # consistency check whether all required files exist for all samples
    for sample in all_samples:
        req_files = [
            os.path.join(workingdir, "filtered_bam/"+sample+".filtered.bam"),
            os.path.join(workingdir, "filtered_bam/"+sample+".filtered.bam.bai")
            ]

        # check for all samples whether all required files exist
        for file in req_files:
            if not os.path.isfile(file):
                print('ERROR: Required file "{}" for sample "{}" specified in '
                      'configuration file is NOT available.'.format(file, sample))
                exit(1)

        
else:
    bamFiles = sorted(glob.glob(os.path.join(str(fromBAM or ''), '*' + bamExt)))
    bamSamples = cf.get_sample_names_bam(bamFiles, bamExt)
    
    bamDict = dict.fromkeys(bamSamples)
    
    for sample in all_samples:
        if sample not in bamDict:
            sys.exit("No bam file found for chip sample {}!".format(sample))
    aligner = "EXTERNAL_BAM"
    indir = fromBAM
    downsample = None

samples = all_samples
if not samples:
    print("\n  Error! NO samples found in dir "+str(indir or '')+"!!!\n\n")
    exit(1)


##filter sample dictionary by the subset of samples listed in the 'name' column of the sample sheet
def filter_dict(sampleSheet,input_dict):
    f=open(sampleSheet,"r")
    nameCol = None
    nCols = None
    names_sub=[]
    for idx, line in enumerate(f):
        cols = line.strip().split("\t")
        if idx == 0:
            nameCol = cols.index("name")
            nCols = len(cols)
            continue
        elif idx == 1:
            if len(cols) - 1 == nCols:
                nameCol += 1
        if not len(line.strip()) == 0:
            names_sub.append(line.split('\t')[nameCol])      
    f.close()
    output_dict = dict((k,v) for k,v in input_dict.items() if k in names_sub)
    return(output_dict)

if sampleSheet:
    filtered_dict = filter_dict(sampleSheet,dict(zip(chip_samples_w_ctrl, [ get_control_name(x) for x in chip_samples_w_ctrl ])))
    genrichDict = cf.sampleSheetGroups(sampleSheet)
else:
    genrichDict = {"all_samples": chip_samples}
