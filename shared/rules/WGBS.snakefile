import os
import re
from operator import is_not
import tempfile
import pandas

###conda environments:
CondaEnvironment='envs/WGBSconda.yml'
mCtCondaEnvironment='envs/methylCtools.yml'
RmdCondaEnvironment='envs/Rmdconda.yml'
CONDA_SHARED_ENV = "envs/shared_environment.yaml"


###get read group info from 1st read in the fastq file

#rule get_RG:
#    input:
#        R1 = "FASTQ/{sample}"+reads[0]+".fastq.gz"
#    output:
#        RGout="FASTQ/{sample}"+reads[0]+".RG.txt"
#    #log:
#    run:
#       for R1,RGout in zip({input.R1},{output.RGout}):
#            with open(RGout,"w") as oo: 
#                RG=get_Read_Group(R1)
#                oo.write(RG)
        
###get automatic cut threshold for hard-trimming of 5' ends
if trimReads=='auto':
    if fqcin:
        rule get_cut_thd:
            input:
                R1zip = fqcin+"/{sample}"+reads[0]+"_fastqc.zip",
                R2zip = fqcin+"/{sample}"+reads[1]+"_fastqc.zip"
            output:
                R12ct= "FastQC_In/{sample}.R12.ct.txt"
            log:"FastQC_In/logs/{sample}.cutThd.log"
            threads: 1
            run:
                for f,g,z,l in zip ({input.R1zip},{input.R2zip},output,log):
                    with open(z, "w") as oo:
                        cutThdRes=calc_cutThd([f,g],fqcin,l,wdir)
                        oo.write('\n'.join('%s\t%s\n' % x for x in cutThdRes))
                os.chdir(wdir)


    rule trimReads:
        input:
            R1 = "FASTQ/{sample}"+reads[0]+".fastq.gz",
            R2 = "FASTQ/{sample}"+reads[1]+".fastq.gz",
            R12ct= "FastQC_In/{sample}.R12.ct.txt"
        output:
            R1cut="FASTQ_Cutadapt/{sample}"+reads[0]+".fastq.gz",
            R2cut="FASTQ_Cutadapt/{sample}"+reads[1]+".fastq.gz"
        #log:"FASTQ_Cutadapt/logs/{sample}.log"
        threads: nthreads
        conda: CONDA_SHARED_ENV
        shell: "ct=($(cat {input.R12ct})); cutadapt -a AGATCGGAAGAGC -A AGATCGGAAGAGC --minimum-length 30  -n 5 -j {threads} -u ${{ct[0]}}  -U ${{ct[1]}} -o {output.R1cut} -p {output.R2cut} {input.R1} {input.R2}"
            

elif trimReads=='user':
    rule trimReads:
        input:
            R1 = "FASTQ/{sample}"+reads[0]+".fastq.gz",
            R2 = "FASTQ/{sample}"+reads[1]+".fastq.gz"
        output:
            R1cut="FASTQ_Cutadapt/{sample}"+reads[0]+".fastq.gz",
            R2cut="FASTQ_Cutadapt/{sample}"+reads[1]+".fastq.gz"
        #log:"FASTQ_Cutadapt/logs/{sample}.log"
        params:
            adapterSeq=adapterSeq,
            trimThreshold=trimThreshold,
            trimOtherArgs=trimOtherArgs
        threads: nthreads
        conda: CONDA_SHARED_ENV
        shell: "cutadapt -a {params.adapterSeq} -A {params.adapterSeq} -q {params.trimThreshold} -m 30 -j {threads} {params.trimOtherArgs} -o {output.R1cut} -p {output.R2cut} {input.R1} {input.R2} " 



if not trimReads is None:
    rule postTrimFastQC:
        input:
            R1cut="FASTQ_Cutadapt/{sample}"+reads[0]+".fastq.gz",
            R2cut="FASTQ_Cutadapt/{sample}"+reads[1]+".fastq.gz"
        output:
            R1fqc="FastQC_Cutadapt/{sample}"+reads[0]+"_fastqc.html",
            R2fqc="FastQC_Cutadapt/{sample}"+reads[1]+"_fastqc.html"
        #log:"FastQC_Cutadapt/logs/{sample}.log"
        params:
            fqcout=os.path.join(wdir,'FastQC_Cutadapt')
        threads: nthreads
        conda: CONDA_SHARED_ENV
        shell: "fastqc --outdir {params.fqcout} -t  {threads} {input.R1cut} {input.R2cut}"

if convRef:
    rule conv_ref:
        input:
            refG=refG
        output:
            crefG=os.path.join('conv_ref',re.sub('.fa','.fa.bwameth.c2t',os.path.basename(refG)))
        #log:"conv_ref/logs/convref.log"
        threads: 1
        conda: CondaEnvironment
        shell:"ln -s {input.refG} " + os.path.join("aux_files",os.path.basename("{input.refG}"))+';bwameth index ' + os.path.join("aux_files",os.path.basename("{input.refG}"))

if not trimReads is None:
    rule map_reads:
        input:
            R1cut="FASTQ_Cutadapt/{sample}"+reads[0]+".fastq.gz",
            R2cut="FASTQ_Cutadapt/{sample}"+reads[1]+".fastq.gz",
            crefG=crefG
        output:
            sbam=temp("bams/{sample}.sorted.bam")
        #log:"bams/logs/{sample}"+".mapping.log"
        params:
            tempdir=tempfile.mkdtemp(suffix='',prefix="{sample}",dir='/data/extended'),
            sortThreads=min(nthreads,4),
            RG=lambda wildcards: RG_dict[wildcards.sample]
        threads: nthreads
        conda: CondaEnvironment
        shell: "bwameth.py --threads  {threads}  --read-group {params.RG} --reference {input.crefG} {input.R1cut} {input.R2cut} | samtools sort -T {params.tempdir} -m 3G -@ {params.sortThreads} -o {output.sbam}"

if trimReads is None:
    rule map_reads:
        input:
            R1="FASTQ/{sample}"+reads[0]+".fastq.gz",
            R2="FASTQ/{sample}"+reads[1]+".fastq.gz",
            crefG=crefG
        output:
            sbam=temp("bams/{sample}.sorted.bam")
        #log:"bams/logs/{sample}"+".mapping.log"
        params:
            tempdir=tempfile.mkdtemp(suffix='',prefix="{sample}",dir='/data/extended'),
            sortThreads=min(nthreads,4),
            RG=lambda wildcards: RG_dict[wildcards.sample]
        threads: nthreads
        conda: CondaEnvironment
        shell: "bwameth.py --threads  {threads}  --read-group {params.RG} --reference {input.crefG} {input.R1} {input.R2} | samtools sort -T {params.tempdir} -m 3G -@ {params.sortThreads} -o {output.sbam}"


rule index_bam:
    input:
        sbam="bams/{sample}.sorted.bam"
    output:
        sbami=temp("bams/{sample}.sorted.bam.bai")
    #params:
    #log:"bams/logs/{sample}"+".indexing.log"
    conda: CONDA_SHARED_ENV
    shell: "samtools index {input.sbam}"

rule rm_dupes:
    input:
        sbami="bams/{sample}.sorted.bam.bai",
        sbam="bams/{sample}.sorted.bam"
    output:
        rmDupbam="bams/{sample}.PCRrm.bam"
    #log:"bams/logs/{sample}"+".PCRdupRm.log"
    params:
        tempdir=tempfile.mkdtemp(suffix='',prefix='',dir='/data/extended')
    threads: nthreads
    conda: CONDA_SHARED_ENV
    shell: "sambamba markdup --remove-duplicates -t {threads} --tmpdir {params.tempdir} {input.sbam} {output.rmDupbam}" 

rule index_PCRrm_bam:
    input:
        sbam="bams/{sample}.PCRrm.bam"
    output:
        sbami="bams/{sample}.PCRrm.bam.bai"
    params:
    #log:"bams/logs/{sample}"+".indexing.log"
    threads: 1
    conda: CONDA_SHARED_ENV
    shell: "samtools index {input.sbam}"


rule get_ran_CG:
    input:
        refG=refG
    output:
        pozF=temp("aux_files/"+re.sub('.fa*','.poz.gz',os.path.basename(refG))),
        ranCG=os.path.join("aux_files",re.sub('.fa','.poz.ran1M.sorted.bed',os.path.basename(refG)))
    #log:"aux_files/genome.get_ranCG.log"
    threads: 1
    conda: mCtCondaEnvironment
    shell: 'set +o pipefail; ' + os.path.join(workflow_tools,'methylCtools') + " fapos {input.refG}  " + re.sub('.gz','',"{output.pozF}") + ';cat '+ re.sub('.gz','',"{output.pozF}") +' | grep "+" - | shuf | head -n 1000000 | awk \'{{print $1, $5, $5+1, $6, $8}}\' - | tr " " "\\t" | sort -k 1,1 -k2,2n - > ' + "{output.ranCG}"
        


rule calc_Mbias:
    input:
        refG=refG,
        rmDupBam="bams/{sample}.PCRrm.bam",
        sbami="bams/{sample}.PCRrm.bam.bai"
    output:
        mbiasTXT="QC_metrics/{sample}.Mbias.txt"
    #log:"QC_metrics/logs/{sample}"+".mbias.log"
    threads: nthreads
    conda: CondaEnvironment
    shell: "MethylDackel mbias {input.refG} {input.rmDupBam} {output.mbiasTXT} -@ {threads} 2>{output.mbiasTXT}"


if intList:
    rule depth_of_cov:
        input:
            refG=refG,
            rmDupBam="bams/{sample}.PCRrm.bam",
            sbami="bams/{sample}.PCRrm.bam.bai",
            ranCG=os.path.join("aux_files",re.sub('.fa','.poz.ran1M.sorted.bed',os.path.basename(refG))),
            intList=intList
        output:
            outFileList=calc_doc(intList,True)
        params:
            auxdir=os.path.join(wdir,"aux_files"),
            OUTlist=lambda wildcards,output: [w.replace('.sample_summary', '') for w in output.outFileList],
            OUTlist0=lambda wildcards,output: [w.replace('.sample_summary', '') for w in output.outFileList][0],
            OUTlist1=lambda wildcards,output: [w.replace('.sample_summary', '') for w in output.outFileList][1],
            #OUTlist2=lambda wildcards,output: [w.replace('.sample_summary', '') for w in output.outFileList][2:],
            auxshell=lambda wildcards,input,output: ';'.join("gatk -Xmx30g -Djava.io.tmpdir=/data/extended  -T DepthOfCoverage -R "+ input.refG +" -o "+ oi +" -I " + input.rmDupBam + " -ct 0 -ct 1 -ct 2 -ct 5 -ct 10 -ct 15 -ct 20 -ct 30 -ct 50  -omitBaseOutput -mmq 10 --partitionType sample -L " + bi for oi,bi in zip([w.replace('.sample_summary', '') for w in output.outFileList][2:],input.intList))
        log:"QC_metrics/logs/{sample}"+".doc.log"
        threads: 1
        conda: CondaEnvironment
        shell: "gatk -Xmx30g -Djava.io.tmpdir=/data/extended -T DepthOfCoverage -R {input.refG} -o {params.OUTlist0} -I {input.rmDupBam} -ct 0 -ct 1 -ct 2 -ct 5 -ct 10 -ct 15 -ct 20 -ct 30 -ct 50  -omitBaseOutput -mmq 10 --partitionType sample ; gatk -Xmx30g -Djava.io.tmpdir=/data/extended  -T DepthOfCoverage -R {input.refG} -o {params.OUTlist1} -I {input.rmDupBam} -ct 0 -ct 1 -ct 2 -ct 5 -ct 10 -ct 15 -ct 20 -ct 30 -ct 50  -omitBaseOutput -mmq 10 --partitionType sample -L {input.ranCG}; {params.auxshell} 2>{log}" 


else:
    rule depth_of_cov:
        input:
            refG=refG,
            rmDupBam="bams/{sample}.PCRrm.bam",
            sbami="bams/{sample}.PCRrm.bam.bai",
            ranCG=os.path.join("aux_files",re.sub('.fa','.poz.ran1M.sorted.bed',os.path.basename(refG)))
        output:
            outFileList=calc_doc(intList,True)
        params:
            auxdir=os.path.join(wdir,"aux_files"),
            OUTlist=lambda wildcards,output: [w.replace('.sample_summary', '') for w in output.outFileList]
        log:"QC_metrics/logs/{sample}"+".doc.log"
        threads: 1
        conda: CondaEnvironment
        shell: "gatk -Xmx30g -Djava.io.tmpdir=/data/extended -T DepthOfCoverage -R {input.refG} -o {params.OUTlist0} -I {input.rmDupBam} -ct 0 -ct 1 -ct 2 -ct 5 -ct 10 -ct 15 -ct 20 -ct 30 -ct 50  -omitBaseOutput -mmq 10 --partitionType sample ; gatk -Xmx30g -Djava.io.tmpdir=/data/extended  -T DepthOfCoverage -R {input.refG} -o {params.OUTlist1} -I {input.rmDupBam} -ct 0 -ct 1 -ct 2 -ct 5 -ct 10 -ct 15 -ct 20 -ct 30 -ct 50  -omitBaseOutput -mmq 10 --partitionType sample -L {input.ranCG} 2>{log}"

if not trimReads is None:
    rule downsample_reads:
        input:
            R1cut="FASTQ_Cutadapt/{sample}"+reads[0]+".fastq.gz",
            R2cut="FASTQ_Cutadapt/{sample}"+reads[1]+".fastq.gz"
        output:
            R1downsampled="FASTQ_downsampled/{sample}"+reads[0]+".fastq.gz",
            R2downsampled="FASTQ_downsampled/{sample}"+reads[1]+".fastq.gz"
        log:"FASTQ_downsampled/logs/{sample}.downsampling.log"
        threads: nthreads
        conda: CONDA_SHARED_ENV
        shell: """
                seqtk sample -s 100 {input.R1cut} 5000000 | pigz -p {threads} -9 > {output.R1downsampled}  
                seqtk sample -s 100 {input.R2cut} 5000000 | pigz -p {threads} -9 > {output.R2downsampled}
               """

    rule conv_rate:
        input:
            R1downsampled="FASTQ_downsampled/{sample}"+reads[0]+".fastq.gz",
            R2downsampled="FASTQ_downsampled/{sample}"+reads[1]+".fastq.gz"
        output:
            R12cr="QC_metrics/{sample}.conv.rate.txt"
        params:
            read_root=lambda wildcards: "FASTQ_downsampled/"+wildcards.sample
        #log:"QC_metrics/logs/{sample}"+".convrate.log"
        threads: 1
        shell: os.path.join(workflow_tools,'conversionRate_KS.sh ')+ "{params.read_root} {output.R12cr}"

else:
    rule downsample_reads:
        input:
            R1="FASTQ/{sample}"+reads[0]+".fastq.gz",
            R2="FASTQ/{sample}"+reads[1]+".fastq.gz"
        output:
            R1downsampled="FASTQ_downsampled/{sample}"+reads[0]+".fastq.gz",
            R2downsampled="FASTQ_downsampled/{sample}"+reads[1]+".fastq.gz"
        log:"FASTQ_downsampled/logs/{sample}.downsampling.log"
        threads: nthreads
        conda: CONDA_SHARED_ENV
        shell: """
                seqtk sample -s 100 {input.R1} 5000000 | pigz -p {threads} -9 > {output.R1downsampled}  
                seqtk sample -s 100 {input.R2} 5000000 | pigz -p {threads} -9 > {output.R2downsampled}
               """
    
    rule conv_rate:
        input:
            R1="FASTQ_downsampled/{sample}"+reads[0]+".fastq.gz",
            R2="FASTQ_downsampled/{sample}"+reads[1]+".fastq.gz"
        output:
            R12cr="QC_metrics/{sample}.conv.rate.txt"
        #log:"QC_metrics/logs/{sample}"+".convrate.log"
        threads: 1
        shell: os.path.join(workflow_tools,'conversionRate_KS.sh ')+ "FASTQ_downsampled/{sample} {output.R12cr}"

rule get_flagstat:
    input:
        rmDupbam="bams/{sample}.PCRrm.bam"
    output:
        fstat="QC_metrics/{sample}.flagstat"
    #log:"QC_metrics/logs/{sample}"+".flagstat.log"
    threads: 1
    conda: CONDA_SHARED_ENV
    shell: "samtools flagstat {input.rmDupbam} > {output.fstat}" 

rule produce_report:
    input:
        doc_res=calc_doc(intList,False),
        R12cr=expand("QC_metrics/{sample}.conv.rate.txt",sample=samples),
        mbiasTXT=expand("QC_metrics/{sample}.Mbias.txt",sample=samples),
        fstat=expand("QC_metrics/{sample}.flagstat",sample=samples)
    output:
        QCrep='QC_metrics/QC_report.pdf'
    params:
        auxdir=os.path.join(wdir,"aux_files")
    #log:"QC_metrics/logs/QCrep.log"
    conda: RmdCondaEnvironment 
    threads: 1
    shell: "cp -v " + os.path.join(workflow_tools,"WGBS_QC_report_template.Rmd")+ " " + os.path.join("aux_files", "WGBS_QC_report_template.Rmd") + ';Rscript -e "rmarkdown::render(\''+os.path.join(wdir,"aux_files", "WGBS_QC_report_template.Rmd")+'\', params=list(QCdir=\'"' + os.path.join(wdir,"QC_metrics") +'"\' ), output_file =\'"'+ os.path.join(wdir,"QC_metrics",'QC_report.pdf"\'')+')"'


if mbias_ignore=="auto":
    rule methyl_extract:
        input:
            rmDupbam="bams/{sample}.PCRrm.bam",
            sbami="bams/{sample}.PCRrm.bam.bai",
            refG=refG,
            mbiasTXT="QC_metrics/{sample}.Mbias.txt"     
        output:
            methTab="methXT/{sample}_CpG.bedGraph"
        params:
            #mbias_ignore=lambda wildcards,input: get_mbias_auto(input.mbiasTXT),
            OUTpfx=lambda wildcards,output: os.path.join(wdir,re.sub('_CpG.bedGraph','',output.methTab))
        #log:"methXT/logs/{sample}.methXT.log"
        threads: nthreads
        conda: CondaEnvironment
        shell: "mi=$(cat {input.mbiasTXT} | sed 's/Suggested inclusion options: //' );MethylDackel extract  -o {params.OUTpfx} -q 10 -p 20 $mi --minDepth 10 --mergeContext --maxVariantFrac 0.25 --minOppositeDepth 5 -@ {threads} {input.refG} " + os.path.join(wdir,"{input.rmDupbam}")
            

else:
    rule methyl_extract:
        input:
            rmDupbam="bams/{sample}.PCRrm.bam",
            sbami="bams/{sample}.PCRrm.bam.bai",
            refG=refG
        output:
            methTab="methXT/{sample}_CpG.bedGraph"
        params:
            mbias_ignore=mbias_ignore,
            OUTpfx=lambda wildcards,output: os.path.join(wdir,re.sub('_CpG.bedGraph','',output.methTab))
        #log:"methXT/logs/{sample}.methXT.log"
        threads: nthreads
        conda: CondaEnvironment
        shell: "MethylDackel extract  -o {params.OUTpfx} -q 10 -p 20 {params.mbias_ignore} --minDepth 10 --mergeContext --maxVariantFrac 0.25 --minOppositeDepth 5 -@ {threads} {input.refG} " + os.path.join(wdir,"{input.rmDupbam}")

if blackList is None:
    rule CpG_filt:
        input:
            methTab="methXT/{sample}_CpG.bedGraph"
        output:
            tabFilt="methXT/{sample}.CpG.filt2.bed"
        params:
            methDir=os.path.join(wdir,"methXT"),
            OUTtemp=lambda wildcards,input: os.path.join(wdir,re.sub('_CpG.bedGraph','.CpG.filt.bed',input.methTab))
        #log:"methXT/logs/{sample}.CpG.filt.log"
        threads: 1
        conda: CondaEnvironment
        shell: "Rscript --no-save --no-restore " + os.path.join(workflow_tools,'WGBSpipe.POM.filt.R ') + "{params.methDir} {input.methTab};mv -v {params.OUTtemp} {output.tabFilt}"

else:
    rule CpG_filt:
        input:
            methTab="methXT/{sample}_CpG.bedGraph",
            blackListF=blackList
        output:
            tabFilt="methXT/{sample}.CpG.filt2.bed"
        params:
            methDir=os.path.join(wdir,"methXT"),
            OUTtemp=lambda wildcards,input: os.path.join(wdir,re.sub('_CpG.bedGraph','.CpG.filt.bed',input.methTab))
        #log:"methXT/logs/{sample}.CpG.filt.log"
        threads: 1
        conda: CondaEnvironment
        shell: "Rscript --no-save --no-restore " + os.path.join(workflow_tools,'WGBSpipe.POM.filt.R ') + "{params.methDir} {input.methTab};bedtools intersect -v -a {params.OUTtemp} -b {input.blackListF} > {output.tabFilt}"


if sampleInfo:
    rule CpG_stats:
        input: expand("methXT/{sample}.CpG.filt2.bed",sample=samples)
        output:
            RDatAll='singleCpG_stats_limma/singleCpG.RData',
            Limdat='singleCpG_stats_limma/limdat.LG.RData',
            MetIN='singleCpG_stats_limma/metilene.IN.txt'
        params:
            statdir=os.path.join(wdir,'singleCpG_stats_limma'),
            sampleInfo=sampleInfo
        #log:"singleCpG_stats_limma/logs/singleCpGstats.log"
        threads: 1
        conda: CondaEnvironment
        shell: "Rscript --no-save --no-restore " + os.path.join(workflow_tools,'WGBSpipe.singleCpGstats.limma.R ') + "{params.statdir} {params.sampleInfo} "  + os.path.join(wdir,"methXT")

    rule run_metilene:
        input:
            MetIN='singleCpG_stats_limma/metilene.IN.txt',
            sampleInfo=sampleInfo
        output:
            MetBed='metilene_out/singleCpG.metilene.bed'
        params:
            DMRout=os.path.join(wdir,'metilene_out')
        #log:"metilene_out/logs/metilene.log"
        threads: nthreads
        conda: CondaEnvironment
        shell: 'metilene -a ' + list(set(pandas.read_table(sampleInfo)['Group']))[0] + ' -b ' + list(set(pandas.read_table(sampleInfo)['Group']))[1] + " -t {threads} {input.MetIN} | sort -k 1,1 -k2,2n > {output.MetBed}"


    rule get_CG_metilene:
        input:
            refG=refG,
            MetBed='metilene_out/singleCpG.metilene.bed',
            pozF="aux_files/"+re.sub('.fa*','.poz.gz',os.path.basename(refG))
        output:
            imdF=temp("aux_files/"+re.sub('.fa*','.CpG.bed',os.path.basename(refG))),
            MetCG=os.path.join("aux_files",re.sub('.fa','.metilene.CpGlist.bed',os.path.basename(refG)))
        params:
            auxdir=os.path.join(wdir,"aux_files")            
        #log:"aux_files/getCG_metilene.log"
        threads: 1
        conda: CondaEnvironment
        shell: 'grep "+"' + " {input.pozF} "+ ' | awk \'{{print $1, $5, $5+1, $6, $8}}\' - | tr " " "\\t" | sort -k 1,1 -k2,2n - > ' + "{output.imdF};"+ "bedtools intersect -wa -a {output.imdF} -b {input.MetBed} > {output.MetCG} ;sleep 300"
            

    rule cleanup_metilene:
        input:
            Limdat='singleCpG_stats_limma/limdat.LG.RData',
            MetBed='metilene_out/singleCpG.metilene.bed',
            MetCG=os.path.join("aux_files",re.sub('.fa','.metilene.CpGlist.bed',os.path.basename(refG))),
            sampleInfo=sampleInfo,
            refG=refG
        output:
            LimBed='metilene_out/singleCpG.metilene.limma.bed',
            LimAnnot='metilene_out/metilene.limma.annotated.txt'
        params:
            DMRout=os.path.join(wdir,'metilene_out')
        #log:'metilene_out/logs/cleanup.log'
        threads: 1
        conda: CondaEnvironment
        shell: 'Rscript --no-save --no-restore ' + os.path.join(workflow_tools,'WGBSpipe.metilene_stats.limma.R ') + "{params.DMRout} " + os.path.join(wdir,"{input.MetBed}") +' ' + os.path.join(wdir,"{input.MetCG}") + ' ' + os.path.join(wdir,"{input.Limdat}") + " {input.sampleInfo} {input.refG}" 


if intList:
    rule get_CG_per_int:
        input:
            intList=intList,
            refG=refG,
            imdF="aux_files/"+re.sub('.fa*','.CpG.bed',os.path.basename(refG))
        output:
            outList=run_int_aggStats(intList,False) #check for full path
        #log:"aux_files/getCG_intList.log"
        params:
            auxshell=lambda wildcards,input,output: ';'.join(["bedtools intersect -wa -a "+ input.imdF + " -b " + bli + ' > ' + oli for bli,oli in zip(input.intList,output.outList) ])+';sleep 300'
        threads: 1
        conda: CondaEnvironment
        shell:"{params.auxshell}"


    if sampleInfo:
        rule intAgg_stats:
            input:
                Limdat='singleCpG_stats_limma/limdat.LG.RData',
                intList=intList,
                refG=refG,
                sampleInfo=sampleInfo,
                aux=run_int_aggStats(intList,False)
            output:
                outFiles=run_int_aggStats(intList,sampleInfo)
            params:
                #auxList=[os.path.join(wdir,"aux_files",re.sub('.fa',re.sub('.bed','.CpGlist.bed',os.path.basename(x)),os.path.basename(refG))) for x in intList],
                auxshell=lambda wildcards,input:';'.join(['Rscript --no-save --no-restore ' + os.path.join(workflow_tools,'WGBSpipe.interval_stats.limma.R ') + os.path.join(wdir,'aggregate_stats_limma ') + li +' '+ aui +' ' + os.path.join(wdir,input.Limdat) + ' '  + input.sampleInfo  for li,aui in zip(intList,[os.path.join(wdir,"aux_files",re.sub('.fa',re.sub('.bed','.CpGlist.bed',os.path.basename(x)),os.path.basename(refG))) for x in intList])])
            #log:'aggregate_stats_limma/logs/aggStats.limma.log'
            threads: 1
            conda: CondaEnvironment
            shell: "{params.auxshell}"


 
