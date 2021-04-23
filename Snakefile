###################################################################################################################################
#
# Copyright 2019-2020 IRD-CNRS-Lyon1 University
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, see <http://www.gnu.org/licenses/> or
# write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston,
# MA 02110-1301, USA.
#
# You should have received a copy of the CeCILL-C license with this program.
# If not see <http://www.cecill.info/licences/Licence_CeCILL-C_V1-en.txt>
#
# Intellectual property belongs to authors and IRD, CNRS, and Lyon 1 University  for all versions
# Version 0.1 written by Mourdas Mohamed
#                                                                                                                                   
####################################################################################################################################


#IMPORT
import json
import os

#Class Color
class bcolors:
    VIOLET    = '\033[95m'
    RED       = '\033[91m'
    BLUE      = '\033[94m'
    CYAN      = '\033[96m'
    GREEN     = '\033[92m'
    WARNING   = '\033[93m'
    FAIL      = '\033[91m'
    BOLD      = '\033[1m'
    END       = '\033[0m'
    UNDERLINE = '\033[4m'

def message_color(color, text):
    return color + text + bcolors.END

# Create ouput folder
os.system("mkdir -p " + config["DATA"]["WORK_DIRECTORY"])

# Remember the parameters associated with the output folder
with open(config["DATA"]["WORK_DIRECTORY"].rstrip("/") + "/params.log", "w") as file:
    file.write(json.dumps(config))


# Get path snakefile
path_snk = ""

i = 0
while i < len(sys.argv) and path_snk == "" :
    if sys.argv[i] == "--snakefile" :
        path_snk = os.path.realpath(sys.argv[i + 1])

    i += 1
#

#os.system("cat `dirname " + path_snk + "`/TrEMOLO.txt")

#CMD DEFINE ENV
env="source `dirname " + path_snk + "`/define_env.sh" 

onsuccess:
    print("DONE NO ERROR DETECTED\n")

onerror:
    print("An error occurred")
    shell("kill -s 9 `ps -f | grep \"TrEMOLO/lib/bash/load.sh\" | awk '$8==\"bash\" {{print $2}}'`")


rule REPORT:
    input:
        genome = config["DATA"]["GENOME"],
        cout=["tmp_snk/rule_tmp_TSD"],

    output:
        

    group: "complement_optionnel",
    params:
        path_snk       = path_snk,
        work_directory = config["DATA"]["WORK_DIRECTORY"].rstrip("/"),

        env            = env, #source environnement

        choice_outsider_sv  = config["CHOICE"]["PIPELINE"]["OUTSIDER_VARIANT"],
        choice_insider_sv   = config["CHOICE"]["PIPELINE"]["INSIDER_VARIANT"],

        INTERMEDIATE_FILE   = config["CHOICE"]["INTERMEDIATE_FILE"],

        CHROM_KEEP       = config["PARAMS"]["OUTSIDER_VARIANT"]["TE_DETECTION"]["CHROM_KEEP"],
        
        #Color message
        cmess          = bcolors.CYAN,
        cfail          = bcolors.FAIL,
        cend           = bcolors.END,
        cbold          = bcolors.BOLD,

    log:
        config["DATA"]["WORK_DIRECTORY"].rstrip("/") + "/log/report",


    shell:
        #TODO broullion
        """

        ###rm -f `ls {params.work_directory}/log/ | grep "^[^.]*$"`
        # for i in `ls {params.work_directory}/log/ | grep "^[^.]*$"`; do 
        #     {params.work_directory}/log/$i
        # done;

        {params.env}
        printf "%s\\n" "{params.cmess} [SNK]--[`date`] BUILD REPORT [^-^] {params.cend}"

        rm -fr {params.work_directory}/REPORT/
        mkdir -p {params.work_directory}/REPORT/
        rm -f {log}.*
        

        path_to_pipline=`dirname {params.path_snk}`

        cp -r ${{path_to_pipline}}/report/* {params.work_directory}/REPORT/

        test -s {params.work_directory}/VALUES_TSD_GROUP_OUTSIDER.csv && \
        python3 ${{path_to_pipline}}/lib/python/conv_js_histo_grouped_ggplot.py \
        {params.work_directory}/VALUES_TSD_GROUP_OUTSIDER.csv data > {params.work_directory}/REPORT/mini_report/js/TSD_histo.js

        test -s {params.work_directory}/VALUES_TSD_INSIDER_GROUP.csv && \
        python3 ${{path_to_pipline}}/lib/python/conv_js_histo_grouped_ggplot.py \
        {params.work_directory}/VALUES_TSD_INSIDER_GROUP.csv data > {params.work_directory}/REPORT/mini_report/js/TSD_INSIDER_histo.js \
        || sed -i '/TSD_INSIDER_histo/d' {params.work_directory}/REPORT/mini_report/outsider.Rmd


        test -s {params.work_directory}/VALUES_TSD_ALL_GROUP.csv && \
        python3 ${{path_to_pipline}}/lib/python/conv_js_histo_grouped_ggplot.py \
        {params.work_directory}/VALUES_TSD_ALL_GROUP.csv data > {params.work_directory}/REPORT/mini_report/js/TSD_ALL_histo.js \
        || sed -i '/TSD_ALL_histo/d' {params.work_directory}/REPORT/mini_report/outsider.Rmd


        samtools faidx {input.genome}
        echo {params.CHROM_KEEP} | tr "," "\n" > chrom.txt 
        
        mkdir -p js

        #create_biocircosgenome.py chrom.txt
        grep -f chrom.txt {input.genome}.fai > .tmp_index.fai
        
        python3 ${{path_to_pipline}}/lib/python/create_biocircosgenome.py .tmp_index.fai > js/bioCircosGenome.js

        size_cut=1000000
        for i in `grep -f chrom.txt .tmp_index.fai | cut -f 1-2 | tr "\t" ":"`; 
        do 
            chrom=`echo $i | cut -d ":" -f 1`
            size_chrom=`echo $i | cut -d ":" -f 2`;
            index=1;
            while [ $index -lt $size_chrom ]; 
            do 
                echo -e $chrom"\t"$index"\t"$(($index+$size_cut))
                index=$(($index+$size_cut));
            done;
        done \
         > dm6_cut_chrom.bed;

        first_chrom=`awk 'NR==1{{print $1}}' .tmp_index.fai`

        rm -f .tmp_index.fai
        

        #COUNT TE OUTSIDER
        if test -s {params.work_directory}/OUTSIDER/TE_DETECTION/POSITION_START_TE.bed; then
            test -s {params.work_directory}/OUTSIDER/TE_DETECTION/POSITION_START_TE.bed && \
            awk 'OFS="\\t"{{split($4, a, ":"); print $1, $2, $3, a[2]"|"a[1], $5}}' {params.work_directory}/OUTSIDER/TE_DETECTION/POSITION_START_TE.bed > {params.work_directory}/POSITION_TE_OUTSIDER.bed
            
            bedtools intersect -a dm6_cut_chrom.bed -b {params.work_directory}/POSITION_TE_OUTSIDER.bed -wa | tr "\t" ":" \
                | sort | uniq -c | sort -k 1 -n \
                | awk 'OFS="\t"{{if(NR==1){{split( $2, a, ":"); print a[1], 0, 1, "HISTOGRAM NB TE", 0;}}; split( $2, a, ":"); print a[1], a[2], a[3], "HISTOGRAM NB TE", $1+1}}'\
                | bedtools sort > HISTOGRAM.txt

            max_value_histo_circos=`cat HISTOGRAM.txt | cut -f 5 | sort -n | tail -n 1`


            python3 ${{path_to_pipline}}/lib/python/Biocircos_PrepareData.py HISTOGRAM HISTOGRAM.txt > js/HISTOGRAM.js
            echo "dico_histo = {{}}" >> js/HISTOGRAM.js

            awk '{{print $4}}' {params.work_directory}/POSITION_TE_OUTSIDER.bed | cut -d "|" -f 1 | sort | uniq > TE_NAME.txt
            for TE in `cat TE_NAME.txt`; do
                grep "\\s${{TE}}|" {params.work_directory}/POSITION_TE_OUTSIDER.bed > POS_TE_$TE.bed

                TE_NAME=`echo ${{TE}} | tr "-" "_" | tr "." "_"`

                bedtools intersect -a dm6_cut_chrom.bed -b POS_TE_$TE.bed -wa | tr "\t" ":" \
                    | sort | uniq -c | sort -k 1 -n \
                    | awk -v chrom_rand="$first_chrom" -v max="$max_value_histo_circos" 'OFS="\t"{{if(NR==1){{split( $2, a, ":"); print chrom_rand, 0, 1, "NB TE", 0; print chrom_rand, 0, 2, "NB TE", max;}}; split( $2, a, ":"); print a[1], a[2], a[3], "NB TE", $1}}'\
                    | bedtools sort > HISTOGRAM_${{TE_NAME}}.txt

                ###echo "TE_NAME = $TE_NAME"
                
                python3 ${{path_to_pipline}}/lib/python/Biocircos_PrepareData.py HISTOGRAM HISTOGRAM_${{TE_NAME}}.txt > js/HISTOGRAM_${{TE_NAME}}.js
                
                echo "dico_histo[\\"${{TE_NAME}}\\"] = HISTOGRAM_${{TE_NAME}}" >> js/HISTOGRAM_${{TE_NAME}}.js
                echo -e "\n" >> js/HISTOGRAM.js
                cat js/HISTOGRAM_${{TE_NAME}}.js >> js/HISTOGRAM.js

                rm -f HISTOGRAM_${{TE_NAME}}.txt POS_TE_$TE.bed HISTOGRAM.txt TE_NAME.txt
                rm -f js/HISTOGRAM_${{TE_NAME}}.js
            done;
        fi;

        
        #COUNT TE INSIDER
        if test -s {params.work_directory}/INSIDER/TE_DETECTION/INSERTION_TE.bed; then
            test -s {params.work_directory}/INSIDER/TE_DETECTION/INSERTION_TE.bed && \
            ###awk 'OFS="\\t"{{split($4, a, ":"); print $1, $2, $3, a[2]"|"a[1]}}' {params.work_directory}/INSIDER/TE_DETECTION/INSERTION_TE.bed > {params.work_directory}/POSITION_TE_INSIDER.bed
            cat {params.work_directory}/INSIDER/TE_DETECTION/INSERTION_TE.bed > {params.work_directory}/POSITION_TE_INSIDER.bed


            bedtools intersect -a dm6_cut_chrom.bed -b {params.work_directory}/POSITION_TE_INSIDER.bed -wa | tr "\t" ":" \
                | sort | uniq -c | sort -k 1 -n \
                | awk 'OFS="\t"{{if(NR==1){{split( $2, a, ":"); print a[1], 0, 1, "HISTOGRAM NB TE", 0;}}; split( $2, a, ":"); print a[1], a[2], a[3], "HISTOGRAM NB TE", $1+1}}'\
                | bedtools sort > HISTOGRAM.txt

            max_value_histo_circos=`cat HISTOGRAM.txt | cut -f 5 | sort -n | tail -n 1`


            python3 ${{path_to_pipline}}/lib/python/Biocircos_PrepareData.py HISTOGRAM HISTOGRAM.txt > js/HISTOGRAM_INSIDER.js
            echo "dico_histo = {{}}" >> js/HISTOGRAM_INSIDER.js

            awk '{{print $4}}' {params.work_directory}/POSITION_TE_INSIDER.bed | cut -d "|" -f 1 | sort | uniq > TE_NAME.txt
            for TE in `cat TE_NAME.txt`; do
                grep "\\s${{TE}}|" {params.work_directory}/POSITION_TE_INSIDER.bed > POS_TE_$TE.bed

                TE_NAME=`echo ${{TE}} | tr "-" "_" | tr "." "_"`

                bedtools intersect -a dm6_cut_chrom.bed -b POS_TE_$TE.bed -wa | tr "\t" ":" \
                    | sort | uniq -c | sort -k 1 -n \
                    | awk -v chrom_rand="$first_chrom" -v max="$max_value_histo_circos" 'OFS="\t"{{if(NR==1){{split( $2, a, ":"); print chrom_rand, 0, 1, "NB TE", 0; print chrom_rand, 0, 2, "NB TE", max;}}; split( $2, a, ":"); print a[1], a[2], a[3], "NB TE", $1}}'\
                    | bedtools sort > HISTOGRAM_${{TE_NAME}}.txt

                ###echo "TE_NAME = $TE_NAME"
                
                python3 ${{path_to_pipline}}/lib/python/Biocircos_PrepareData.py HISTOGRAM HISTOGRAM_${{TE_NAME}}.txt > js/HISTOGRAM_${{TE_NAME}}.js
                
                echo "dico_histo[\\"${{TE_NAME}}\\"] = HISTOGRAM_${{TE_NAME}}" >> js/HISTOGRAM_${{TE_NAME}}.js
                echo -e "\n" >> js/HISTOGRAM.js
                cat js/HISTOGRAM_${{TE_NAME}}.js >> js/HISTOGRAM_INSIDER.js

                rm -f HISTOGRAM_${{TE_NAME}}.txt POS_TE_$TE.bed HISTOGRAM.txt TE_NAME.txt
                rm -f js/HISTOGRAM_${{TE_NAME}}.js
            done;
        fi;

        

        cp js/* {params.work_directory}/REPORT/mini_report/js/
        rm -fr js
        rm -f dm6_cut_chrom.bed

        pwd
        old_path=`readlink -f {params.work_directory}/..`
        cd {params.work_directory}/REPORT/mini_report/

        
        #INSIDER
        if [ {params.choice_insider_sv} != "True" ]; then
            rm -f insider.Rmd
        else
            ! test -s ../../INSIDER/FREQ_GLOBAL/DEPTH_TE_INSIDER.csv && \
               sed -i 's/r FREQIN, eval=TRUE,/r FREQIN, eval=FALSE,/g' insider.Rmd  && \
               sed -i '/FREQUENCE/d' insider.Rmd
            cat insider.Rmd >> index.Rmd
            mv insider.Rmd insider.Rmd.tmp
        fi;

        
        #OUTSIDER
        if [ {params.choice_outsider_sv} != "True" ]; then
            rm -f outsider.Rmd
        else
            cat outsider.Rmd >> index.Rmd
            mv outsider.Rmd outsider.Rmd.tmp
        fi;

        

        #REMOVE OR COUNT INSIDER
        if ! test -s ../../INSIDER/TE_DETECTION/INSERTION.csv ; then
            sed -i 's/r insider1, eval=TRUE,/r, eval=FALSE,/g' index.Rmd
            
            #DELET LINE INUTILE
            sed -i '/INSIDER/d' index.Rmd
            sed -i '/TE_INSIDER/d' index.Rmd
        else
            awk -F "\t" 'BEGIN{{print "name,value"}}NR>1{{print $2","$3}}' ../../INSIDER/TE_DETECTION/INSERTION_COUNT_TE.csv  > tmp.csv
            python3 ${{path_to_pipline}}/lib/python/conv_js_histo_grouped.py tmp.csv data > js/COUNT_TE_INSIDER.js
            rm -f tmp.csv
        fi;

        
        #REMOVE OR COUNT OUTSIDER
        if ! test -s ../../OUTSIDER/TE_DETECTION/FILTER_BLAST_SEQUENCE_INDEL_vs_DBTE.csv ; then
            sed -i 's/r NB_OUTSIDER, eval=TRUE,/r, eval=FALSE,/g' index.Rmd
            sed -i 's/r TSD, eval=TRUE,/r, eval=FALSE,/g' index.Rmd
            sed -i 's/r FREQ, eval=TRUE,/r, eval=FALSE,/g' index.Rmd

            sed -i '/FILTER_BLAST_SEQUENCE_INDEL_vs_DBTE/d' index.Rmd
        else
            awk -F "\t" 'BEGIN{{print "name,value"}}NR>1{{print $2","$3}}' ../../OUTSIDER/TE_DETECTION/FILTER_BLAST_SEQUENCE_INDEL_vs_DBTE_COUNT.csv  > tmp.csv
            python3 ${{path_to_pipline}}/lib/python/conv_js_histo_grouped.py tmp.csv data > js/COUNT_TE_OUTSIDER.js
            
            rm -f tmp.csv
        fi;

        if ! test -e ../../VALUES_TSD_GROUP_OUTSIDER.csv; then
            sed -i 's/r TSD, eval=TRUE,/r, eval=FALSE,/g' index.Rmd
        fi;

        make

        cp -r ./lib ./js ./web/

        path_to_report=`readlink -f ../report.html`

        printf "%s\\n" "{params.cmess} [SNK]--[`date`]--[INFO] CHECK $path_to_report [^-^] {params.cend}"

        
        rm -f dm6_cut_chrom.bed {params.work_directory}/POSITION_TE_OUTSIDER.bed
        
        cd $old_path
        pwd
        if [ {params.INTERMEDIATE_FILE} = "False" ]; then
            rm -fr {params.work_directory}/OUTSIDER
            rm -fr {params.work_directory}/INSIDER
            rm -f  {params.work_directory}/VALUES_TSD*
        fi


        rm -f COMBINE_TE.csv
        rm -f chrom.txt
        rm -f test.csv
        """



rule TSD :
    input:
        cout=["tmp_snk/rule_tmp_FIND_TE_ON_REF"],
        #directory(config["DATA"]["WORK_DIRECTORY"].rstrip("/") + "/" + "ET_FIND_FA"),
        fasta_TE  = config["DATA"]["TE_DB"],
        genome    = config["DATA"]["GENOME"],
        

    output:
        #config["DATA"]["WORK_DIRECTORY"].rstrip("/") + "/VALUES_TSD_GROUP_OUTSIDER.csv",
        #directory(config["DATA"]["WORK_DIRECTORY"].rstrip("/") + "/" + "TSD"),
        temp(touch("tmp_snk/rule_tmp_TSD")),

    group: "complement_optionnel",
    params:
        path_snk       = path_snk,
        work_directory = config["DATA"]["WORK_DIRECTORY"].rstrip("/"),

        env            = env, #source environnement

        choice_outsider_sv  = config["CHOICE"]["PIPELINE"]["OUTSIDER_VARIANT"],

        #TSD
        FILE_SIZE_TE_TSD = config["PARAMS"]["OUTSIDER_VARIANT"]["TSD"]["FILE_SIZE_TE_TSD"],
        SIZE_FLANK       = config["PARAMS"]["OUTSIDER_VARIANT"]["TSD"]["SIZE_FLANK"],

        #Color message
        cmess          = bcolors.CYAN,
        cfail          = bcolors.FAIL,
        cend           = bcolors.END,
        cbold          = bcolors.BOLD,

    log:
        config["DATA"]["WORK_DIRECTORY"].rstrip("/") + "/log/TSD",

    shell:
        #TODO broullion
        """
        {params.env}

        rm -f {log}.*

        ###echo -e "x\ty\tfill" > {params.work_directory}/VALUES_TSD.csv;
        echo -e "x\ty\tcondition" > {params.work_directory}/VALUES_TSD_GROUP_OUTSIDER.csv

        printf "\\n%s\\n\\n" "{params.cmess} [SNK]--[`date`] --- TSD --- {params.cend}"

        mkdir -p {params.work_directory}/OUTSIDER/TE_DETECTION/TSD ;
        path_to_pipline=`dirname {params.path_snk}`
        
        read_directory="{params.work_directory}/OUTSIDER/READ_FASTQ_TE"
        fasta_dir_find="{params.work_directory}/OUTSIDER/FASTA_FIND"

        echo "   SIZE FLANKING SEQUENCE : {params.SIZE_FLANK}"

        if [ {params.choice_outsider_sv} = "True" ]; then
            
            NB_FILE=`ls {params.work_directory}/OUTSIDER/ET_FIND_FA | wc -l` ;
            i=0 ;
            for TE_found_fa in `ls {params.work_directory}/OUTSIDER/ET_FIND_FA/`; do
                
                ###echo "[TSD:snk] $i/$NB_FILE" ;

                nameTE=`echo $TE_found_fa | grep -o "_[^_]*\." | grep -o "[^_]*" | sed 's/\.$//g'` ;
                
                ! test -s {params.FILE_SIZE_TE_TSD} && message_fail "  Warning FILE {params.FILE_SIZE_TE_TSD} NOT FOUND\n"
                
                SIZE_TSD=`test -n "{params.FILE_SIZE_TE_TSD}" && test -s {params.FILE_SIZE_TE_TSD} && grep -w "${{nameTE}}" {params.FILE_SIZE_TE_TSD} || echo "NONE"`; # EX: ZAM 4 :or: -1
                #SIZE_TSD=`grep -w "${{nameTE}}" ${{path_to_pipline}}/lib/TSD/TE_SIZE_TSD.txt || echo "NONE"`; # EX: ZAM 4 :or: -1
                
                echo "TE : $nameTE"
                
                if [[ $SIZE_TSD != "NONE" ]]; then
                    SIZE_TSD=`echo $SIZE_TSD | awk '{{print $2}}'`;
                    echo "SIZE-TSD : $SIZE_TSD"

                    #echo "TE=$nameTE ; SIZE TSD=$SIZE_TSD" 
                    
                    (bash ${{path_to_pipline}}/lib/bash/load.sh &) || echo
                    sh ${{path_to_pipline}}/lib/TSD/find_fq_to_fasta.sh {params.work_directory}/OUTSIDER/ET_FIND_FA/$TE_found_fa \
                       ${{read_directory}} \
                       ${{fasta_dir_find}} >> {log}.out 2>> {log}.err;



                    echo "sseqid", "qseqid", "pident", "size_per", "size_el", "mismatch", "gapopen", "qstart", "qend", "sstart", "send", "evalue", "bitscore" | tr -d " " | tr "," "\t" > test.csv
                    awk 'NR>1 && OFS="\t"{{print $1, $2, $3, $4, $5, "mismatch", "gapopen", $6, $7, $8, $9, "evalue", "bitscore"}}' {params.work_directory}/OUTSIDER/TE_DETECTION/COMBINE_TE.csv  >> test.csv

                    sh ${{path_to_pipline}}/lib/TSD/tsd_te.sh {params.work_directory}/OUTSIDER/ET_FIND_FA/$TE_found_fa \
                        ${{read_directory}} \
                        ${{fasta_dir_find}} \
                        {input.fasta_TE} \
                        {params.SIZE_FLANK} \
                        $SIZE_TSD {params.work_directory}/OUTSIDER/TE_DETECTION/COMBINE_TE.csv >> {log}.out 2>> {log}.err || (message_fail "ERROR FOUND TSD PLEASE CHECK {log}.out, {log}.err")

                    mv total_results_tsd.txt {params.work_directory}/OUTSIDER/TE_DETECTION/TSD/TSD_${{nameTE}}.txt
                    #mv total_results_tsd_${{nameTE}}.txt {params.work_directory}/OUTSIDER/TE_DETECTION/TSD/TSD_${{nameTE}}.txt ;

                    sh ${{path_to_pipline}}/lib/TSD/revise_TSD.sh {input.genome} \
                        {params.work_directory}/OUTSIDER/TE_DETECTION/TSD/TSD_${{nameTE}}.txt \
                        {params.SIZE_FLANK} \
                        $SIZE_TSD >> {log}.out 2>> {log}.err;
                        
                    sh ${{path_to_pipline}}/lib/bash/end_load.sh;
                else
                    SIZE_TSD=-1;
                    #echo "SIZE-TSD = $SIZE_TSD"

                    #echo "TE=$nameTE ; SIZE TSD=?" 
                    
                    (bash ${{path_to_pipline}}/lib/bash/load.sh &) || echo
                    sh ${{path_to_pipline}}/lib/TSD/find_fq_to_fasta.sh {params.work_directory}/OUTSIDER/ET_FIND_FA/$TE_found_fa \
                       ${{read_directory}} \
                       ${{fasta_dir_find}} >> {log}.out 2>> {log}.err;

                    echo "sseqid", "qseqid", "pident", "size_per", "size_el", "mismatch", "gapopen", "qstart", "qend", "sstart", "send", "evalue", "bitscore" | tr -d " " | tr "," "\t" > test.csv
                    awk 'NR>1 && OFS="\t"{{print $1, $2, $3, $4, $5, "mismatch", "gapopen", $6, $7, $8, $9, "evalue", "bitscore"}}' {params.work_directory}/OUTSIDER/TE_DETECTION/COMBINE_TE.csv  >> test.csv

                    sh ${{path_to_pipline}}/lib/TSD/tsd_te.sh {params.work_directory}/OUTSIDER/ET_FIND_FA/$TE_found_fa \
                        ${{read_directory}} \
                        ${{fasta_dir_find}} \
                        {input.fasta_TE} \
                        {params.SIZE_FLANK} \
                        $SIZE_TSD {params.work_directory}/OUTSIDER/TE_DETECTION/COMBINE_TE.csv >> {log}.out 2>> {log}.err;

                    mv total_results_tsd.txt {params.work_directory}/OUTSIDER/TE_DETECTION/TSD/TSD_${{nameTE}}.txt
                    #mv total_results_tsd_${{nameTE}}.txt {params.work_directory}/OUTSIDER/TE_DETECTION/TSD/TSD_${{nameTE}}.txt ;

                    if [ 0 -ne `grep "^(" {params.work_directory}/OUTSIDER/TE_DETECTION/TSD/TSD_${{nameTE}}.txt | grep "OK" -c` ]; then
                        SIZE_TSD_MOY=`grep "^(" {params.work_directory}/OUTSIDER/TE_DETECTION/TSD/TSD_${{nameTE}}.txt | grep "OK" | tr -d ")" | cut -d "," -f 6 | awk 'BEGIN{{somme=0}}{{somme+=$0}}END{{print int(somme/NR)}}'`
                        echo "SIZE-TSD-MEAN : $SIZE_TSD_MOY ;"

                        sh ${{path_to_pipline}}/lib/TSD/revise_TSD.sh {input.genome} \
                            {params.work_directory}/OUTSIDER/TE_DETECTION/TSD/TSD_${{nameTE}}.txt \
                            {params.SIZE_FLANK} \
                            $SIZE_TSD_MOY >> {log}.out 2>> {log}.err;
                    fi;
                        
                    sh ${{path_to_pipline}}/lib/bash/end_load.sh;
                fi;
                
                TOTAL=`grep "^OK/total" {params.work_directory}/OUTSIDER/TE_DETECTION/TSD/TSD_${{nameTE}}.txt | tr -d " " | cut -d ":" -f 2 | cut -d "/" -f 2`
                NB_TSD_OK=`grep "^OK/total" {params.work_directory}/OUTSIDER/TE_DETECTION/TSD/TSD_${{nameTE}}.txt | tr -d " " | cut -d ":" -f 2 | cut -d "/" -f 1`
                NB_TSD_KO=`grep "^KO/total" {params.work_directory}/OUTSIDER/TE_DETECTION/TSD/TSD_${{nameTE}}.txt | tr -d " " | cut -d ":" -f 2 | cut -d "/" -f 1`
                NB_TSD_K_gap_O=`grep "^K-O/total" {params.work_directory}/OUTSIDER/TE_DETECTION/TSD/TSD_${{nameTE}}.txt | tr -d " " | cut -d ":" -f 2 | cut -d "/" -f 1`


                if test -e {params.work_directory}/OUTSIDER/TE_DETECTION/TSD/TSD_${{nameTE}}_KO_corrected.txt ; then
                    NB_TSD_OK_corrected=`grep "OK/total" {params.work_directory}/OUTSIDER/TE_DETECTION/TSD/TSD_${{nameTE}}_KO_corrected.txt | tr -d " " | cut -d ":" -f 2 | cut -d "/" -f 1`
                    NB_TSD_KO_corrected=`grep "KO/total" {params.work_directory}/OUTSIDER/TE_DETECTION/TSD/TSD_${{nameTE}}_KO_corrected.txt | tr -d " " | cut -d ":" -f 2 | cut -d "/" -f 1`
                else
                    NB_TSD_OK_corrected=0;
                    NB_TSD_KO_corrected=0;
                fi;

                OK_K_gap_O=$(($NB_TSD_OK + $NB_TSD_K_gap_O + $NB_TSD_OK_corrected));
                            
                PERCENT=$(($OK_K_gap_O*100/$TOTAL))

                ###KO=$(($NB_TSD_KO-$NB_TSD_OK_corrected))
                KO=$(($TOTAL-$OK_K_gap_O));

                echo "TOTAL-TE:$TOTAL ;   TSD [OK]:$NB_TSD_OK ✔;   TSD [K-O]:$NB_TSD_K_gap_O ;   TSD [KO]:$KO ✘;   TSD CORRECTED [KO]:$NB_TSD_OK_corrected ;  "

                ###echo -e "${{nameTE}}\t${{PERCENT}}\tTE" >> {params.work_directory}/VALUES_TSD.csv

                echo -e "${{nameTE}}\t${{OK_K_gap_O}}\tTSD [OK]" >> {params.work_directory}/VALUES_TSD_GROUP_OUTSIDER.csv
                echo -e "${{nameTE}}\t${{KO}}\tTSD [KO]" >> {params.work_directory}/VALUES_TSD_GROUP_OUTSIDER.csv
                
                i=$(($i + 1)) ;
                printf "%s\\n" "{params.cmess} [SNK]--[`date`] [TSD:snk] : $i/$NB_FILE {params.cend}"
            done;

        fi;


        ## TE INSIDER 
        if test -s {params.work_directory}/INSIDER/TE_DETECTION/INSERTION.csv && [ `cat {params.work_directory}/INSIDER/TE_DETECTION/INSERTION.csv | wc -l` -ge 2 ]; then
                
            rm -f {params.work_directory}/VALUES_TSD_INSIDER_GROUP.csv
            rm -f {params.work_directory}/VALUES_TSD_INSIDER.csv

            printf "\\n%s\\n\\n" "{params.cmess} [SNK] TSD TE ASSEMBLED {params.cend}"
            mkdir -p {params.work_directory}/INSIDER/TE_DETECTION/TSD/
            
            awk 'NR>1 {{ print $1 }}' {params.work_directory}/INSIDER/TE_DETECTION/INSERTION.csv | sort -u > TE_name.txt

            NB_TE=`cat TE_name.txt | wc -l`

            e=0;

            show_step="$e/$NB_TE : TSD TE ASSEMBLED "
            number_of_char=`echo "$show_step" | wc -c`
            number_of_char=$(($number_of_char-1));
            printf "\b%.0s" `seq 1 $number_of_char`
            printf "$show_step";

            for TE in `cat TE_name.txt`; do
                #echo "$TE"
                grep "^$TE\s" {params.work_directory}/INSIDER/TE_DETECTION/INSERTION.csv | awk 'OFS="\t"{{split($2, a, ":"); split(a[6], b, "-"); print a[5], b[1], b[2], $1"|"a[1]}}' > INS_$TE.bed
                rm -f total_results_tsd.txt
                
                for i in `cat INS_$TE.bed | tr "\t" ":"`; 
                do 
                    echo $i | tr ":" "\t" > TE.bed;
                    bedtools getfasta -fi {input.genome} -bed TE.bed > TE.fasta

                    ID=`cat TE.bed | cut -f 4 | cut -d "|" -f 2`
                    #echo "ID = $ID"
                    
                    strand=`grep -w $ID {params.work_directory}/INSIDER/TE_DETECTION/INSERTION.csv | awk 'OFS="\t"{{split($2, a, ":"); print a[7]}}'`
                    #echo "ID = $ID; strand = $strand;"
                    
                    cat TE.bed | awk -v size_flank="{params.SIZE_FLANK}" 'OFS="\t"{{print $1, $2-size_flank, $2; print $1, $3, $3+size_flank;}}' > FLANK.bed;
                    bedtools getfasta -fi {input.genome} -bed FLANK.bed > FLANK.fasta

                    python3 ${{path_to_pipline}}/lib/TSD/find_tsd.py FLANK.fasta TE.fasta {params.SIZE_FLANK} $ID $strand -1 >> total_results_tsd.txt 
                done;

                bash ${{path_to_pipline}}/lib/TSD/TSD_VG.sh {params.work_directory}/INSIDER/TE_DETECTION/INSERTION.csv {input.genome}

                nameTE=$TE

                mv total_results_tsd.txt {params.work_directory}/INSIDER/TE_DETECTION/TSD/TSD_${{nameTE}}.txt

                rm -f TE.bed INS_$TE.bed ;
                rm -f TE.fasta FLANK.fasta ;

                e=$(($e+1));

                show_step="$e/$NB_TE : TSD TE ASSEMBLED "
                number_of_char=`echo "$show_step" | wc -c`
                number_of_char=$(($number_of_char-1));
                printf "\b%.0s" `seq 1 $number_of_char`
                printf "$show_step";

                
                TOTAL=`grep "^OK/total" {params.work_directory}/INSIDER/TE_DETECTION/TSD/TSD_${{nameTE}}.txt | tr -d " " | cut -d ":" -f 2 | cut -d "/" -f 2`
                NB_TSD_OK=`grep "^OK/total" {params.work_directory}/INSIDER/TE_DETECTION/TSD/TSD_${{nameTE}}.txt | tr -d " " | cut -d ":" -f 2 | cut -d "/" -f 1`
                NB_TSD_KO=`grep "^KO/total" {params.work_directory}/INSIDER/TE_DETECTION/TSD/TSD_${{nameTE}}.txt | tr -d " " | cut -d ":" -f 2 | cut -d "/" -f 1`
                NB_TSD_K_gap_O=`grep "^K-O/total" {params.work_directory}/INSIDER/TE_DETECTION/TSD/TSD_${{nameTE}}.txt | tr -d " " | cut -d ":" -f 2 | cut -d "/" -f 1`

                OK_K_gap_O=$(($NB_TSD_OK + $NB_TSD_K_gap_O));
                            
                PERCENT=$(($OK_K_gap_O*100/$TOTAL))

                KO=$(($TOTAL-$OK_K_gap_O));

                echo "TOTAL-TE:$TOTAL ;   TSD [OK]:$NB_TSD_OK ;   TSD [K-O]:$NB_TSD_K_gap_O ;   TSD [KO]:$KO ;"

                ##echo -e "${{nameTE}}\t${{PERCENT}}\tTE" >> {params.work_directory}/VALUES_TSD_INSIDER.csv

                echo -e "${{nameTE}}\t${{OK_K_gap_O}}\tTSD [OK]" >> {params.work_directory}/VALUES_TSD_INSIDER_GROUP.csv
                echo -e "${{nameTE}}\t${{KO}}\tTSD [KO]" >> {params.work_directory}/VALUES_TSD_INSIDER_GROUP.csv
                
                printf "%s\\n" "{params.cmess} [SNK]--[`date`] [TSD:snk] : $e/$NB_TE {params.cend}"

            done;
            rm -f FLANK.bed TE.bed TE_name.txt
            echo


            #** TDS ALL **#
            echo -e "x\ty\tcondition" > {params.work_directory}/VALUES_TSD_ALL_GROUP.csv
            for TE in `cat {params.work_directory}/VALUES_TSD_GROUP_OUTSIDER.csv {params.work_directory}/VALUES_TSD_INSIDER_GROUP.csv | awk 'NR>1' | cut -f 1 | sort -u`; do
                ###echo "TE : $TE"
                NBOK1=`grep -w "^$TE" {params.work_directory}/VALUES_TSD_GROUP_OUTSIDER.csv | grep OK | cut -f 2 || echo "0"`;
                NBOK2=`grep -w "^$TE" {params.work_directory}/VALUES_TSD_INSIDER_GROUP.csv | grep OK | cut -f 2 || echo "0"`;

                if [ ! -n "$NBOK1" ]; then
                    NBOK1=0;
                fi;

                if [ ! -n "$NBOK2" ]; then
                    NBOK2=0;
                fi;

                NBKO1=`grep -w "^$TE" {params.work_directory}/VALUES_TSD_GROUP_OUTSIDER.csv | grep KO | cut -f 2 || echo "0"`;
                NBKO2=`grep -w "^$TE" {params.work_directory}/VALUES_TSD_INSIDER_GROUP.csv | grep KO | cut -f 2 || echo "0"`;

                if [ ! -n "$NBKO1" ]; then
                    NBKO1=0;
                fi;

                if [ ! -n "$NBKO2" ]; then
                    NBKO2=0;
                fi;

                echo -e "$TE\t$(($NBOK1+$NBOK2))\tTSD [OK]" >> {params.work_directory}/VALUES_TSD_ALL_GROUP.csv;
                echo -e "$TE\t$(($NBKO1+$NBKO2))\tTSD [KO]" >> {params.work_directory}/VALUES_TSD_ALL_GROUP.csv;
            done;

            awk 'BEGIN{{print "x\ty\tcondition"}}{{print $0}}' {params.work_directory}/VALUES_TSD_INSIDER_GROUP.csv > {params.work_directory}/tmp.csv
            mv {params.work_directory}/tmp.csv {params.work_directory}/VALUES_TSD_INSIDER_GROUP.csv
        fi;

        #rm -f {params.work_directory}/TE_REPORT_total_find.fasta;
        rm -f TSM_OK.txt;
        rm -fr {params.work_directory}/OUTSIDER/TE_DETECTION/TSD/DIR_SEQ_TE_READ_POS
        rm -f {params.work_directory}/OUTSIDER/FASTA_FIND/*.fasta.*
        rm -fr DIR_SEQ_TE_READ_POS
        #test -d DIR_SEQ_TE_READ_POS && \
        #test -d {params.work_directory}/OUTSIDER/TE_DETECTION/TSD/ && \
        #mv DIR_SEQ_TE_READ_POS {params.work_directory}/OUTSIDER/TE_DETECTION/TSD/ || echo

        """



rule FIND_TE_ON_REF :
    input:
        ref         = config["DATA"]["REFERENCE"],
        genome_real = config["DATA"]["WORK_DIRECTORY"].rstrip("/") + "/OUTSIDER/TE_TOWARD_GENOME/genome.out.fasta",
        fasta_TE    = config["DATA"]["TE_DB"],
        all_te      = config["DATA"]["WORK_DIRECTORY"].rstrip("/") + "/OUTSIDER/TE_DETECTION/FILTER_BLAST_SEQUENCE_INDEL_vs_DBTE.csv",
        sam         = config["DATA"]["WORK_DIRECTORY"].rstrip("/") + "/OUTSIDER/INSIDER_VR/pm_against_ref.sam",
        delta       = config["DATA"]["WORK_DIRECTORY"].rstrip("/") + "/OUTSIDER/INSIDER_VR/pm_against_ref.sam.delta",
        bed         = config["DATA"]["WORK_DIRECTORY"].rstrip("/") + "/OUTSIDER/INSIDER_VR/assemblytics_out.Assemblytics_structural_variants.bed",
        stats       = config["DATA"]["WORK_DIRECTORY"].rstrip("/") + "/OUTSIDER/INSIDER_VR/assemblytics_out.Assemblytics_assembly_stats.txt",
        cout=["tmp_snk/rule_tmp_FIND_SV_ON_REF"],
    output:
        temp(touch("tmp_snk/rule_tmp_FIND_TE_ON_REF")),
        

    group: "complement_optionnel",
    params:
        path_snk       = path_snk,
        work_directory = config["DATA"]["WORK_DIRECTORY"].rstrip("/"),

        env            = env, #source environnement

        #INTEGRATE_TE_TO_GENOME
        PUT_ID               = config["PARAMS"]["OUTSIDER_VARIANT"]["INTEGRATE_TE_TO_GENOME"]["PUT_ID"],
        PUT_SEQUENCE_DB_TE   = config["PARAMS"]["OUTSIDER_VARIANT"]["INTEGRATE_TE_TO_GENOME"]["PUT_SEQUENCE_DB_TE"],

        pars_bln_option_insider = config["PARAMS"]["INSIDER_VARIANT"]["PARS_BLN_OPTION"],


        #Color message
        cmess          = bcolors.CYAN,
        cfail          = bcolors.FAIL,
        cend           = bcolors.END,
        cbold          = bcolors.BOLD,

    log:
        config["DATA"]["WORK_DIRECTORY"].rstrip("/") + "/log/FIND_TE_ON_REF",


    shell:
        #TODO broullion
        """
        {params.env}
        path_to_pipline=`dirname {params.path_snk}`

        mkdir -p {params.work_directory}/OUTSIDER/FIND_TE_ON_REF/
        rm -f {log}.*
        
        printf "\\n%s\\n\\n" "{params.cmess} [SNK]--[`date`] GET TE INSIDER {params.cend}"

        {params.env}
        path_to_pipline=`dirname {params.path_snk}`
        
        mkdir -p {params.work_directory}/INSIDER/TE_INSIDER_VR/

        array_type=( "INSERTION" "Repeat_expansion" "Tandem_expansion" )
        for type in "${{array_type[@]}}"
        do
            echo "type=${{type}}";
            grep -i ${{type}} {input.bed} | awk '{{print $10":"$4}}' | awk -v type="${{type}}" -F ":" 'OFS="\t"{{split($2, a, "-"); print $1 , a[1], a[2], $4":"$3":"type}}' > {params.work_directory}/INSIDER/TE_INSIDER_VR/${{type}}.bed
            test -s {params.work_directory}/INSIDER/TE_INSIDER_VR/${{type}}.bed || echo "[SNK  INFO]: ${{type}}.bed IS EMPTY"
            
            bedtools getfasta -fi {input.genome_real} -bed {params.work_directory}/INSIDER/TE_INSIDER_VR/${{type}}.bed -name > {params.work_directory}/INSIDER/TE_INSIDER_VR/tmp_${{type}}_SEQ.fasta
            test -s {params.work_directory}/INSIDER/TE_INSIDER_VR/tmp_${{type}}_SEQ.fasta || echo "[SNK  INFO]: tmp_${{type}}_SEQ.fasta IS EMPTY"
            
            test -s {params.work_directory}/INSIDER/TE_INSIDER_VR/tmp_${{type}}_SEQ.fasta && sh ${{path_to_pipline}}/lib/bash/get_seq_with_id.sh {params.work_directory}/INSIDER/TE_INSIDER_VR/tmp_${{type}}_SEQ.fasta {params.work_directory}/INSIDER/TE_INSIDER_VR/${{type}}_SEQ.fasta || echo fin
            
            test -s {params.work_directory}/INSIDER/TE_INSIDER_VR/${{type}}_SEQ.fasta || echo "[SNK  INFO]: ${{type}}_SEQ.fasta IS EMPTY"
        done;
        
        cat {params.work_directory}/INSIDER/TE_INSIDER_VR/Tandem_expansion_SEQ.fasta {params.work_directory}/INSIDER/TE_INSIDER_VR/Repeat_expansion_SEQ.fasta {params.work_directory}/INSIDER/TE_INSIDER_VR/INSERTION_SEQ.fasta > {params.work_directory}/INSIDER/TE_INSIDER_VR/INSERTION_SEQ_ALL.fasta
        cat {params.work_directory}/INSIDER/TE_INSIDER_VR/INSERTION_SEQ_ALL.fasta > {params.work_directory}/INSIDER/TE_INSIDER_VR/INSERTION_SEQ.fasta
        
        array_type_deletion=( "DELETION" "Repeat_contraction" "Tandem_contraction" );
        for type in "${{array_type_deletion[@]}}"
        do
            grep -i ${{type}}  {input.bed} | awk  -v type="$type" 'OFS="\t"{{print $1, $2, $3, $4":"$6":"type}}' > {params.work_directory}/INSIDER/TE_INSIDER_VR/${{type}}.bed

            bedtools getfasta -fi {input.ref}  -bed {params.work_directory}/INSIDER/TE_INSIDER_VR/${{type}}.bed -name > {params.work_directory}/INSIDER/TE_INSIDER_VR/${{type}}_SEQ.fasta
        done;
        
        cat {params.work_directory}/INSIDER/TE_INSIDER_VR/Tandem_contraction_SEQ.fasta {params.work_directory}/INSIDER/TE_INSIDER_VR/Repeat_contraction_SEQ.fasta {params.work_directory}/INSIDER/TE_INSIDER_VR/DELETION_SEQ.fasta > {params.work_directory}/INSIDER/TE_INSIDER_VR/DELETION_SEQ_ALL.fasta
        cat {params.work_directory}/INSIDER/TE_INSIDER_VR/DELETION_SEQ_ALL.fasta > {params.work_directory}/INSIDER/TE_INSIDER_VR/DELETION_SEQ.fasta

        
        array_type=( "INSERTION" "Repeat_expansion" "Tandem_expansion" "DELETION" "Repeat_contraction" "Tandem_contraction" )
        for type in "${{array_type[@]}}"
        do
            echo -e "\nTYPE : $type";

            if test -s {params.work_directory}/INSIDER/TE_INSIDER_VR/${{type}}_SEQ.fasta; then
                
                awk 'BEGIN{{header="";}}{{if(substr($0, 1, 1) == ">"){{header=$0;}}else if(length($0)>30){{print header"\\n"$0}}}}' {params.work_directory}/INSIDER/TE_INSIDER_VR/${{type}}_SEQ.fasta > {params.work_directory}/INSIDER/TE_INSIDER_VR/tmp.fasta
                
                cat {params.work_directory}/INSIDER/TE_INSIDER_VR/tmp.fasta > {params.work_directory}/INSIDER/TE_INSIDER_VR/${{type}}_SEQ.fasta

                makeblastdb -in {input.fasta_TE} -dbtype nucl  2> {log}.err 1> {log}.out;

                blastn -db {input.fasta_TE} \
                -query {params.work_directory}/INSIDER/TE_INSIDER_VR/${{type}}_SEQ.fasta \
                -outfmt 6 \
                -out {params.work_directory}/INSIDER/TE_INSIDER_VR/${{type}}.bln 2> {log}.err 1> {log}.out;
                
                test -s {params.work_directory}/INSIDER/TE_INSIDER_VR/${{type}}.bln && \
                    python3 ${{path_to_pipline}}/lib/python/global_sv_id.py {params.pars_bln_option_insider} \
                         --combine_name {params.work_directory}/INSIDER/TE_INSIDER_VR/${{type}}_COMBINE_TE.csv \
                        {params.work_directory}/INSIDER/TE_INSIDER_VR/${{type}}.bln \
                        {input.fasta_TE} \
                        {params.work_directory}/INSIDER/TE_INSIDER_VR/${{type}}.csv 

                test -s {params.work_directory}/INSIDER/TE_INSIDER_VR/${{type}}.csv && \
                awk 'NR>1{{print $1}}' {params.work_directory}/INSIDER/TE_INSIDER_VR/${{type}}.csv | sort | uniq -c | sort -k 1 -n | \
                    awk 'BEGIN{{print "x\ty\tz"}} OFS="\t"{{print "", $2, $1}}' > {params.work_directory}/INSIDER/TE_INSIDER_VR/${{type}}_COUNT_TE.csv

            fi;
        done;
        
        rm -f {params.work_directory}/INSIDER/TE_INSIDER_VR/tmp_*

        
        cd {params.work_directory}/INSIDER/TE_INSIDER_VR/
        
        rm -f Repeat*
        rm -f Tandem*
        rm -f *SEQ_ALL.fasta
        rm -f tmp*

        """


rule FIND_SV_ON_REF :
    input:
        ref         = config["DATA"]["REFERENCE"],
        genome_real = config["DATA"]["WORK_DIRECTORY"].rstrip("/") + "/OUTSIDER/TE_TOWARD_GENOME/genome.out.fasta",
        fasta_TE    = config["DATA"]["TE_DB"],
        all_te      = config["DATA"]["WORK_DIRECTORY"].rstrip("/") + "/OUTSIDER/TE_DETECTION/FILTER_BLAST_SEQUENCE_INDEL_vs_DBTE.csv",
        cout=["tmp_snk/rule_tmp_TE_TOWARD_GENOME"],
    output:
        temp(touch("tmp_snk/rule_tmp_FIND_SV_ON_REF")),
        sam   = config["DATA"]["WORK_DIRECTORY"].rstrip("/") + "/OUTSIDER/INSIDER_VR/pm_against_ref.sam",
        delta = config["DATA"]["WORK_DIRECTORY"].rstrip("/") + "/OUTSIDER/INSIDER_VR/pm_against_ref.sam.delta",
        bed   = config["DATA"]["WORK_DIRECTORY"].rstrip("/") + "/OUTSIDER/INSIDER_VR/assemblytics_out.Assemblytics_structural_variants.bed",
        stats = config["DATA"]["WORK_DIRECTORY"].rstrip("/") + "/OUTSIDER/INSIDER_VR/assemblytics_out.Assemblytics_assembly_stats.txt",
        

    group: "complement_optionnel",
    params:
        path_snk       = path_snk,
        work_directory = config["DATA"]["WORK_DIRECTORY"].rstrip("/"),

        env            = env, #source environnement

        #INTEGRATE_TE_TO_GENOME
        PUT_ID               = config["PARAMS"]["OUTSIDER_VARIANT"]["INTEGRATE_TE_TO_GENOME"]["PUT_ID"],
        PUT_SEQUENCE_DB_TE   = config["PARAMS"]["OUTSIDER_VARIANT"]["INTEGRATE_TE_TO_GENOME"]["PUT_SEQUENCE_DB_TE"],

        #Color message
        cmess          = bcolors.CYAN,
        cfail          = bcolors.FAIL,
        cend           = bcolors.END,
        cbold          = bcolors.BOLD,

    log:
        config["DATA"]["WORK_DIRECTORY"].rstrip("/") + "/log/FIND_TE_ON_REF",


    shell:
        #TODO broullion
        """
        {params.env}
        path_to_pipline=`dirname {params.path_snk}`

        rm -f {log}.*
        
        printf "\\n%s\\n\\n" "{params.cmess} [SNK]--[`date`] GET SV INSIDER {params.cend}"


        mkdir -p {params.work_directory}/OUTSIDER/INSIDER_VR/
        mkdir -p {params.work_directory}/log/
        #cd {params.work_directory}/OUTSIDER/INSIDER_VR/


        path_to_pipline=`dirname {params.path_snk}`

        minimap2 -ax asm5 --cs -t3 {input.ref} {input.genome_real} > {output.sam} 2> {params.work_directory}/log/pm_contigs_against_ref.sam.log

        python3 ${{path_to_pipline}}/lib/python/sam2delta.py {output.sam};
        

        python3 ${{path_to_pipline}}/lib/python/Assemblytics_uniq_anchor.py \
        --delta {output.delta} \
        --unique-length 10000 \
        --out {params.work_directory}/OUTSIDER/INSIDER_VR/assemblytics_out \
        --keep-small-uniques;


        perl ${{path_to_pipline}}/lib/perl/Assemblytics_between_alignments.pl \
        {params.work_directory}/OUTSIDER/INSIDER_VR/assemblytics_out.coords.tab \
        50 \
        10000 \
        all-chromosomes \
        exclude-longrange \
        bed > {params.work_directory}/OUTSIDER/INSIDER_VR/assemblytics_out.variants_between_alignments.bed;


        python3 ${{path_to_pipline}}/lib/python/Assemblytics_within_alignment.py \
        --delta {params.work_directory}/OUTSIDER/INSIDER_VR/assemblytics_out.Assemblytics.unique_length_filtered_l10000.delta \
        --min 50 > {params.work_directory}/OUTSIDER/INSIDER_VR/assemblytics_out.variants_within_alignments.bed;


        cat {params.work_directory}/OUTSIDER/INSIDER_VR/assemblytics_out.variants_between_alignments.bed \
        {params.work_directory}/OUTSIDER/INSIDER_VR/assemblytics_out.variants_within_alignments.bed \
        > {output.bed}
        

        path_ref=`readlink -f {input.ref}`
        path_genome=`readlink -f {input.genome_real}`
        

        old_path=`pwd`
        
        cd {params.work_directory}/OUTSIDER/INSIDER_VR/
        python3 ${{path_to_pipline}}/lib/python/filter_gap_SVs.py ${{path_ref}} ${{path_genome}}
        cd ${{old_path}}

        name_ref=`basename {input.ref}`
        name_query=`basename {input.genome_real}`

        printf "%s\\n" "{params.cmess} [SNK]--[`date`]--[INFO] REFERENCE : $name_ref {params.cend}"
        printf "%s\\n\\n" "{params.cmess} [SNK]--[`date`]--[INFO] GENOME : $name_query {params.cend}"

        sed -i "s/file1/${{name_ref}}/g" {output.stats}
        sed -i "s/file2/${{name_query}}/g" {output.stats}

        """

rule TE_TOWARD_GENOME :
    input:
        #config["DATA"]["WORK_DIRECTORY"].rstrip("/") + "/TE_REPORT_total_find.fasta",
        cout=["tmp_snk/rule_tmp_GET_SEQ_TE"],
        fasta_TE     = config["DATA"]["TE_DB"],
        genome       = config["DATA"]["GENOME"],
        all_te       = config["DATA"]["WORK_DIRECTORY"].rstrip("/") + "/OUTSIDER/TE_DETECTION/FILTER_BLAST_SEQUENCE_INDEL_vs_DBTE.csv",
        snif_seqs    = config["DATA"]["WORK_DIRECTORY"].rstrip("/") + "/OUTSIDER/VARIANT_CALLING/SEQUENCE_INDEL.fasta",
        
    output:
        config["DATA"]["WORK_DIRECTORY"].rstrip("/") + "/OUTSIDER/TE_TOWARD_GENOME/genome.out.fasta",
        temp(touch("tmp_snk/rule_tmp_TE_TOWARD_GENOME")),

    group: "complement_optionnel",
    params:
        path_snk       = path_snk,
        work_directory = config["DATA"]["WORK_DIRECTORY"].rstrip("/"),

        env            = env, #source environnement

        #INTEGRATE_TE_TO_GENOME
        PUT_ID              = config["PARAMS"]["OUTSIDER_VARIANT"]["INTEGRATE_TE_TO_GENOME"]["PUT_ID"],
        PUT_SEQUENCE_DB_TE  = config["PARAMS"]["OUTSIDER_VARIANT"]["INTEGRATE_TE_TO_GENOME"]["PUT_SEQUENCE_DB_TE"],

        #FOR DETECTION ON ASM
        choice_insider_sv   = config["CHOICE"]["PIPELINE"]["INSIDER_VARIANT"],

        #Color message
        cmess          = bcolors.CYAN,
        cfail          = bcolors.FAIL,
        cend           = bcolors.END,
        cbold          = bcolors.BOLD,

    log:
        config["DATA"]["WORK_DIRECTORY"].rstrip("/") + "/log/TE_TOWARD_GENOME",


    shell:
        #TODO broullion
        """
        {params.env}
        path_to_pipline=`dirname {params.path_snk}`

        mkdir -p {params.work_directory}/OUTSIDER/TE_TOWARD_GENOME/
        rm -f {log}.*
        rm -f {params.work_directory}/OUTSIDER/TE_TOWARD_GENOME/genome.out.fasta.fai
        
        awk 'NR>1{{print $2}}' {input.all_te} | sed 's/:[+-]$//g' > {params.work_directory}/OUTSIDER/TE_TOWARD_GENOME/ID.txt

        rm -f {params.work_directory}/OUTSIDER/TE_TOWARD_GENOME/SEQUENCE_INDEL_DB_TE.fasta && touch {params.work_directory}/OUTSIDER/TE_TOWARD_GENOME/SEQUENCE_INDEL_DB_TE.fasta

        if [ {params.PUT_SEQUENCE_DB_TE} = "True" ]  || [ {params.choice_insider_sv} = "True" ]; then

            #SEQ INDEL to Cannonical SEQ
            for ID in `cat "{params.work_directory}/OUTSIDER/TE_TOWARD_GENOME/ID.txt"`; do
                seq_old=`grep "$ID" {input.snif_seqs} -A 1 | grep -v ">"`
                TE=`grep "$ID" {input.all_te} | cut -f 1`
                strand=`grep "$ID" {input.all_te} | grep ":[-+]" -o | tr -d ":"`

                #echo "$ID == $TE";

                if [[ $strand = "+" ]]; then
                    seq_TE_cannonical=`grep -w "$TE" {input.fasta_TE} -A 1 | grep -v ">"`
                else
                    seq_TE_cannonical=`grep -w "$TE" {input.fasta_TE} -A 1 | grep -v ">" | tr "ATGC" "TACG" | rev`
                fi
                
                size_seq=`echo ${{seq_TE_cannonical}} | awk '{{print length($0)}}'`

                echo ">$ID" >> {params.work_directory}/OUTSIDER/TE_TOWARD_GENOME/SEQUENCE_INDEL_DB_TE.fasta
                #echo ">$ID::$TE:$size_seq" >> {params.work_directory}/OUTSIDER/TE_TOWARD_GENOME/SEQUENCE_INDEL_DB_TE.fasta
                ID_TE=`echo ${{ID}} | cut -d ":" -f 5`

                #WARNING SEQ WITH NUMBER
                if [ {params.PUT_ID} = "True" ] || [ {params.choice_insider_sv} = "True" ]; then
                    echo "${{ID_TE}}$seq_TE_cannonical" >> {params.work_directory}/OUTSIDER/TE_TOWARD_GENOME/SEQUENCE_INDEL_DB_TE.fasta
                else
                    echo "$seq_TE_cannonical" >> {params.work_directory}/OUTSIDER/TE_TOWARD_GENOME/SEQUENCE_INDEL_DB_TE.fasta
                fi;
            done; 

            ##INTEGRATION SEQUENCE DB
            awk 'BEGIN{{start=0; header=0;}} OFS="\t"{{if(substr($0, 1, 1) == ">"){{split($0, sp, ":"); header=$0; start=sp[3];}}else{{print header, start, start+length($0)}} }}' \
            {params.work_directory}/OUTSIDER/TE_TOWARD_GENOME/SEQUENCE_INDEL_DB_TE.fasta | sed 's/^>//g' > {params.work_directory}/OUTSIDER/TE_TOWARD_GENOME/SEQUENCE_INDEL.bed

            grep -w -f {params.work_directory}/OUTSIDER/TE_TOWARD_GENOME/ID.txt {params.work_directory}/OUTSIDER/TE_TOWARD_GENOME/SEQUENCE_INDEL_DB_TE.fasta -A 1 \
            > {params.work_directory}/OUTSIDER/TE_TOWARD_GENOME/SEQUENCE_INDEL_as_TE.fasta

        else

            #INTEGRATION SEQUENCE TE READS
            
        
            if [ {params.PUT_ID} = "True" ]; then
                grep -f {params.work_directory}/OUTSIDER/TE_TOWARD_GENOME/ID.txt {params.work_directory}/OUTSIDER/VARIANT_CALLING/SEQUENCE_INDEL.fasta -A 1 | \
                awk '{{if(substr($0, 1, 1) == ">"){{head=$0; }}else if(length($0) >= 30 ){{split(head, a, ":"); print head"\\n"a[5]$0}}}}' | grep -v "\\-\\-" \
                > {params.work_directory}/OUTSIDER/TE_TOWARD_GENOME/SEQUENCE_INDEL_as_TE.fasta

                awk 'BEGIN{{start=0; header=0;}} OFS="\t"{{if(substr($0, 1, 1) == ">"){{split($0, sp, ":"); header=$0; start=sp[3];}}else{{print header, start, start+length($0)}} }}' \
                {params.work_directory}/OUTSIDER/TE_TOWARD_GENOME/SEQUENCE_INDEL_as_TE.fasta | sed 's/^>//g' > {params.work_directory}/OUTSIDER/TE_TOWARD_GENOME/SEQUENCE_INDEL.bed
            else
                grep -w -f {params.work_directory}/OUTSIDER/TE_TOWARD_GENOME/ID.txt {params.work_directory}/OUTSIDER/VARIANT_CALLING/SEQUENCE_INDEL.fasta -A 1 \
                > {params.work_directory}/OUTSIDER/TE_TOWARD_GENOME/SEQUENCE_INDEL_as_TE.fasta
            fi;
        fi;

        
        grep -f {params.work_directory}/OUTSIDER/TE_TOWARD_GENOME/ID.txt {params.work_directory}/OUTSIDER/TE_TOWARD_GENOME/SEQUENCE_INDEL.bed \
        > {params.work_directory}/OUTSIDER/TE_TOWARD_GENOME/SEQUENCE_INDEL_as_TE.bed

        #FASTA TO FORMAT bed for script vr_to_genome
        while read l; do 
            to_find=`echo $l | cut -d " " -f 1`; 
            chrom=`echo $l | cut -d ":" -f 1`;  
            start=`echo $l | cut -d " " -f 2`; 
            end=`echo $l | cut -d " " -f 3`; 
            TE=`grep -w "$to_find" {input.all_te} | cut -f 1 || echo "NONE"` ;
            ID=`echo $l | cut -f 1 | cut -d":" -f 5`;

            if [ $TE != "NONE" ]; then
                echo "$chrom $start $end $TE:$ID"; 
            fi;

        done < {params.work_directory}/OUTSIDER/TE_TOWARD_GENOME/SEQUENCE_INDEL_as_TE.bed | tr " " "\t" > {params.work_directory}/OUTSIDER/TE_TOWARD_GENOME/SEQUENCE_INDEL_TE.bed


        ## INTEGRATE TE TO GENOME
        python3 ${{path_to_pipline}}/lib/python/vr_to_genome.py \
        -ob {params.work_directory}/OUTSIDER/TE_TOWARD_GENOME/TRUE_POSITION_TE.bed \
        -og {params.work_directory}/OUTSIDER/TE_TOWARD_GENOME/genome.out.fasta \
        {params.work_directory}/OUTSIDER/TE_TOWARD_GENOME/SEQUENCE_INDEL_TE.bed \
        {input.genome} \
        {params.work_directory}/OUTSIDER/TE_TOWARD_GENOME/SEQUENCE_INDEL_as_TE.fasta


        ## CHECKING TE INTEGRATED ##
        bedtools getfasta -fi {params.work_directory}/OUTSIDER/TE_TOWARD_GENOME/genome.out.fasta \
        -bed {params.work_directory}/OUTSIDER/TE_TOWARD_GENOME/TRUE_POSITION_TE.bed \
        -name > {params.work_directory}/OUTSIDER/TE_TOWARD_GENOME/TRUE_POSITION_TE.fasta

        TOTAL_TE=`awk 'NR>1' {input.all_te} | wc -l`
        NB_SEQ_FOUND=`grep -w -f {params.work_directory}/OUTSIDER/TE_TOWARD_GENOME/TRUE_POSITION_TE.fasta {params.work_directory}/OUTSIDER/TE_TOWARD_GENOME/SEQUENCE_INDEL_as_TE.fasta -c`
        
        echo "NB_TE INTEGRATE: $NB_SEQ_FOUND ;   TOTAL_TE: $TOTAL_TE ;"
        
        rm -f {params.work_directory}/OUTSIDER/TE_TOWARD_GENOME/genome.out.fasta.fai #important to delet this
        rm -f {params.work_directory}/OUTSIDER/TE_TOWARD_GENOME/ID.txt;
        rm -f {params.work_directory}/TE_REPORT_total_find.fasta
        rm -f {params.work_directory}/OUTSIDER/TE_TOWARD_GENOME/SEQUENCE_INDEL_TE*
        """

rule GET_SEQ_TE :
    input:
        config["DATA"]["WORK_DIRECTORY"].rstrip("/") + "/OUTSIDER/ID_BEST_READ_TE.txt",
        all_te            = config["DATA"]["WORK_DIRECTORY"].rstrip("/") + "/OUTSIDER/TE_DETECTION/FILTER_BLAST_SEQUENCE_INDEL_vs_DBTE.csv",
        snif_seqs         = config["DATA"]["WORK_DIRECTORY"].rstrip("/") + "/OUTSIDER/VARIANT_CALLING/SEQUENCE_INDEL.fasta",
        cout=["tmp_snk/rule_tmp_extract_read"],

    output:
        directory(config["DATA"]["WORK_DIRECTORY"].rstrip("/") + "/OUTSIDER/ET_FIND_FA/"),
        config["DATA"]["WORK_DIRECTORY"].rstrip("/") + "/TE_REPORT_total_find.fasta",
        temp(touch("tmp_snk/rule_tmp_GET_SEQ_TE")),

    params:
        work_directory = config["DATA"]["WORK_DIRECTORY"].rstrip("/"),

        env            = env, #source environnement

    shell:
        """
        {params.env}
        mkdir -p {params.work_directory}/OUTSIDER/ET_FIND_FA ;
        
        rep="{params.work_directory}/OUTSIDER/ET_FIND_FA" 
        prefix="TE_REPORT"

        awk '{{print $2}}' {input.all_te} > {params.work_directory}/.tmp_id.txt
        grep -f {params.work_directory}/.tmp_id.txt {params.work_directory}/OUTSIDER/TE_DETECTION/COMBINE_TE.csv > {params.work_directory}/.tmp_combine.csv
        echo "sseqid", "qseqid", "pident", "size_per", "size_el", "mismatch", "gapopen", "qstart", "qend", "sstart", "send", "evalue", "bitscore" | tr -d " " | tr "," "\t" > test.csv
        awk 'NR>1 && OFS="\t"{{print $1, $2, $3, $4, $5, "mismatch", "gapopen", $6, $7, $8, $9, "evalue", "bitscore"}}' {params.work_directory}/.tmp_combine.csv  >> test.csv

        cat test.csv | sed -e 's/:[-+]//g' > {params.work_directory}/tmp_TE_all.csv
        
        ###head {params.work_directory}/tmp_TE_all.csv
        
        awk -v dir="$rep" -v prefix="$prefix" 'BEGIN{{OFS="\t"}} NR>1 {{
            if($8<$9){{print $2, $8-1, $9  >> dir"/"prefix"_find_"$1".bed"}} 
            else{{
                print $2, $9-1, $8  >> dir"/"prefix"_find_"$1".bed"
            }} 
        }}' {params.work_directory}/tmp_TE_all.csv ;

        for i in `ls {params.work_directory}/OUTSIDER/ET_FIND_FA | grep ".bed$"`; do
            bedtools getfasta -fi {input.snif_seqs} \
               -bed {params.work_directory}/OUTSIDER/ET_FIND_FA/$i > {params.work_directory}/OUTSIDER/ET_FIND_FA/TE_REPORT_FOUND_`echo $i \
                | grep -o "_[^_]*\." | grep -o "[^_]*" | sed 's/\.$//g'`.fasta; 
        done ;

        rm -f {params.work_directory}/.tmp*
        rm -f {params.work_directory}/OUTSIDER/ET_FIND_FA/*.bed ;
        rm -f {params.work_directory}/tmp*
        cat {params.work_directory}/OUTSIDER/ET_FIND_FA/* > {params.work_directory}/TE_REPORT_total_find.fasta ;

        """


rule extract_read :
    input:
        all_te   = config["DATA"]["WORK_DIRECTORY"].rstrip("/") + "/OUTSIDER/TE_DETECTION/FILTER_BLAST_SEQUENCE_INDEL_vs_DBTE.csv",
        bln      = config["DATA"]["WORK_DIRECTORY"].rstrip("/") + "/OUTSIDER/TE_DETECTION/BLAST_SEQUENCE_INDEL_vs_DBTE.bln",
        vcf      = config["DATA"]["WORK_DIRECTORY"].rstrip("/") + "/OUTSIDER/VARIANT_CALLING/SV.vcf",
        read     = config["DATA"]["SAMPLE"],
        fasta_TE = config["DATA"]["TE_DB"],
        cout=["tmp_snk/rule_tmp_FREQUENCE"],

    output:
        config["DATA"]["WORK_DIRECTORY"].rstrip("/") + "/OUTSIDER/ID_BEST_READ_TE.txt",
        temp(touch("tmp_snk/rule_tmp_extract_read")),

    params:
        path_snk       = path_snk,
        work_directory = config["DATA"]["WORK_DIRECTORY"].rstrip("/"),

        env            = env, #source environnement

        #Choice
        FLYE           = config["CHOICE"]["OUTSIDER_VARIANT"]["LOCAL_ASSEMBLY"]["FLYE"],
        WTDGB          = config["CHOICE"]["OUTSIDER_VARIANT"]["LOCAL_ASSEMBLY"]["WTDGB"],

        CHROM_KEEP     = config["PARAMS"]["OUTSIDER_VARIANT"]["TE_DETECTION"]["CHROM_KEEP"],

        #Color message
        cmess          = bcolors.CYAN,
        cfail          = bcolors.FAIL,
        cend           = bcolors.END,
        cbold          = bcolors.BOLD,
    log:
        config["DATA"]["WORK_DIRECTORY"].rstrip("/") + "/log/extract_read"

    shell:
        """
        {params.env}
        rm -f {log}*

        printf "%s\\n" "{params.cmess} [SNK]--[`date`] GET READS AND ASSEMBLY [^-^] {params.cend}"

        rm -fr {params.work_directory}/OUTSIDER/READ_FASTQ_TE
        mkdir -p {params.work_directory}/OUTSIDER/READ_FASTQ_TE ;

        #BUG
        test -s {params.work_directory}/all_TE_assembly.bln && \
        cat {params.work_directory}/all_TE_assembly.bln > {params.work_directory}/all_TE_assembly_before.bln

        path_to_pipline=`dirname {params.path_snk}`

        ##only TE found
        awk 'NR>1 {{print $2}}' {input.all_te} | cut -d":" -f 5 > {params.work_directory}/ID_TE_SV_REPORT.txt ; 

        python3 ${{path_to_pipline}}/lib/python/extract_region_reads_vcf.py -c {params.CHROM_KEEP} \
          {input.vcf} \
         -d {params.work_directory}/OUTSIDER/ID_READS_TE \
         -i {params.work_directory}/ID_TE_SV_REPORT.txt ;


        makeblastdb -in {input.fasta_TE} -dbtype nucl ;

        NB_FILE=`ls {params.work_directory}/OUTSIDER/ID_READS_TE | wc -l` ;
        i=0 ;

        show_step="$i/$NB_FILE TE "
        number_of_char=`echo "$show_step" | wc -c`
        number_of_char=$(($number_of_char-1));
        printf "\b%.0s" `seq 1 $number_of_char`
        printf "$show_step";

        for read_file in `ls {params.work_directory}/OUTSIDER/ID_READS_TE`; do

            region=`echo $read_file | grep -o "[_].*\." | grep -o "[^_].*[^.]"` ;
            
            if ! test -s {params.work_directory}/OUTSIDER/READ_FASTQ_TE/reads_${{region}}.fastq; then

                id=`echo $read_file | grep -o "[_].*\." | grep -o "[^_].*[^.]" | cut -d":" -f 2`
                nb_read=`cat {params.work_directory}/OUTSIDER/ID_READS_TE/$read_file | sort | uniq | wc -l`
                TE=`grep ":$id:[0-9]*:[IP]" {input.all_te} | cut -f 1 || echo "NONE"`


                printf "%s\\n" "      {params.cmess} [SNK]--[`date`] [extract_read:snk] $read_file {params.cend}" >> {log}.out
                printf "%s\\n" "      {params.cmess} [SNK]--[`date`] [extract_read:snk] [extract_read:snk] $i/$NB_FILE : nb_read=$nb_read : id=$id {params.cend}" >> {log}.out

                (grep -w $id {params.work_directory}/ID_TE_SV_REPORT.txt >> {log}.err && \
                 samtools fqidx {input.read} -r {params.work_directory}/OUTSIDER/ID_READS_TE/$read_file > \
                 {params.work_directory}/OUTSIDER/READ_FASTQ_TE/reads_${{region}}.fq) || echo "$id NOT FOUND" >> {log}.err ;

                ## FORMAT FASTQ
                test -s {params.work_directory}/OUTSIDER/READ_FASTQ_TE/reads_${{region}}.fq && \
                python3 ${{path_to_pipline}}/lib/python/fastq_to_fastq.py \
                 {params.work_directory}/OUTSIDER/READ_FASTQ_TE/reads_${{region}}.fq \
                 {params.work_directory}/OUTSIDER/READ_FASTQ_TE/reads_${{region}}.fastq >> {log}.out 2>> {log}.err;

                test -s {params.work_directory}/OUTSIDER/READ_FASTQ_TE/reads_${{region}}.fastq || echo "[ERROR EXTRACT READ] $id" >> {log}.err
                
                rm -f {params.work_directory}/OUTSIDER/READ_FASTQ_TE/reads_${{region}}.fq
            fi;

            i=$(($i + 1));

            show_step="$i/$NB_FILE TE "
            number_of_char=`echo "$show_step" | wc -c`
            number_of_char=$(($number_of_char-1));
            printf "\b%.0s" `seq 1 $number_of_char`
            printf "$show_step";
        done;

        printf "%s\\n" "{params.cmess} [SNK]--[`date`] EXTRACT DONE ! {params.cend}"

        NB_REGION=`ls {params.work_directory}/OUTSIDER/ID_READS_TE | wc -l`;
        NB_READS=`ls {params.work_directory}/OUTSIDER/READ_FASTQ_TE | wc -l`;

        #### echo "     [extract_read:snk] $NB_READS AND $NB_REGION";

        ## GET BEST ID TE
        awk 'NR>1 {{print $2}}' {input.all_te} | cut -d ":" -f 5,8 > {params.work_directory}/tmp_ID_RD_SEQ.txt

        grep -w -f {params.work_directory}/ID_TE_SV_REPORT.txt {params.work_directory}/tmp_ID_RD_SEQ.txt > {params.work_directory}/ID_RD_SEQ.txt

        for i in `cat {params.work_directory}/ID_RD_SEQ.txt`; 
        do  
            ID=`echo $i | cut -d ":" -f 1`; 
            num=`echo $i | cut -d ":" -f 2`; 
            name_file=`ls {params.work_directory}/OUTSIDER/ID_READS_TE/ | grep -w "$ID"`; 

            awk -v num="$num" 'NR-1 == num' {params.work_directory}/OUTSIDER/ID_READS_TE/$name_file > {params.work_directory}/OUTSIDER/ID_BEST_READ_TE.txt;
        done;

        rm -f {params.work_directory}/ID_RD_SEQ.txt {params.work_directory}/ID_TE_SV_REPORT.txt

        """


rule FREQUENCE :
    input:
        fasta_TE = config["DATA"]["TE_DB"],
        bam      = config["DATA"]["WORK_DIRECTORY"].rstrip("/") + "/OUTSIDER/MAPPING/MAPPING_POSTION_TE.bam",
        all_te   = config["DATA"]["WORK_DIRECTORY"].rstrip("/") + "/OUTSIDER/TE_DETECTION/FILTER_BLAST_SEQUENCE_INDEL_vs_DBTE.csv",
        genome   = config["DATA"]["GENOME"],
        cout=["tmp_snk/rule_tmp_FREQ_GLOBAL"],

    output:
        temp(touch("tmp_snk/rule_tmp_FREQUENCE")),
        depth_te  = config["DATA"]["WORK_DIRECTORY"].rstrip("/") + "/OUTSIDER/FREQ_AFTER/DEPTH_TE.csv",
        
        
    params:
        path_snk        = path_snk,
        work_directory  = config["DATA"]["WORK_DIRECTORY"].rstrip("/"),

        pars_bln_option = config["PARAMS"]["OUTSIDER_VARIANT"]["PARS_BLN_OPTION"],

        env             = env, #source environnement

        call_sv         = config["CHOICE"]["OUTSIDER_VARIANT"]["CALL_SV"],

        CHROM_KEEP      = config["PARAMS"]["OUTSIDER_VARIANT"]["TE_DETECTION"]["CHROM_KEEP"],


        cfail          = bcolors.FAIL,
        cmess          = bcolors.CYAN,
        cend           = bcolors.END,
    log:
        config["DATA"]["WORK_DIRECTORY"].rstrip("/") + "/log/FREQUENCE"

    shell:
        """
        {params.env}
        printf "%s\\n" "{params.cmess} [SNK]--[`date`] FREQUENCE [^-^] {params.cend}"

        path_to_pipline=`dirname {params.path_snk}`

        #mkdir -p {params.work_directory}/FREQ_BEFORE
        mkdir -p {params.work_directory}/OUTSIDER/FREQ_AFTER


        samtools index {params.work_directory}/OUTSIDER/MAPPING/MAPPING_POSTION_TE.bam 
        samtools view -h {params.work_directory}/OUTSIDER/MAPPING/MAPPING_POSTION_TE.bam > {params.work_directory}/MAPPING_POSTION_TE.sam

        # svim alignment --read_names \
        #     --insertion_sequences \
        #     --minimum_depth 1 {params.work_directory}/FREQ_BEFORE {params.work_directory}/OUTSIDER/MAPPING/MAPPING_POSTION_TE.bam {input.genome} 2> svim.log

        # python3 ${{path_to_pipline}}/lib/python/get_seq_vcf.py {params.work_directory}/FREQ_BEFORE/variants.vcf {params.work_directory}/FREQ_BEFORE/variants.fasta
        
        # makeblastdb -in {input.fasta_TE} -dbtype nucl 2> {log}.err;
        # blastn -db {input.fasta_TE} \
        # -query {params.work_directory}/FREQ_BEFORE/variants.fasta \
        # -outfmt 6 \
        # -out {params.work_directory}/FREQ_BEFORE/variants.fasta \
        # {params.work_directory}/FREQ_BEFORE/variants.bln 2>> {log}.err;

        # python3 ${{path_to_pipline}}/lib/python/parse_blast_main.py \
        #     {params.work_directory}/FREQ_BEFORE/variants.bln \
        #     {input.fasta_TE} \
        #     {params.work_directory}/FREQ_BEFORE/FILTER_BLAST_SEQUENCE_INDEL_vs_DBTE.csv -c


        # awk 'OFS="\t"{{split($2, a, ":"); print a[1], a[3], $5}}' {params.work_directory}/FREQ_BEFORE/FILTER_BLAST_SEQUENCE_INDEL_vs_DBTE.csv \
        # > TE_POSITION_SIZE.txt

        ## Warning TODO BEFORE
        awk 'OFS="\t"{{split($2, a, ":"); print a[1], a[3], $5}}' {input.all_te} \
        > {params.work_directory}/OUTSIDER/FREQ_AFTER/TE_POSITION_SIZE.txt


        ${{path_to_pipline}}/lib/bash/awk_not_cliping.sh {params.work_directory}/OUTSIDER/FREQ_AFTER/TE_POSITION_SIZE.txt \
        {params.work_directory}/MAPPING_POSTION_TE.sam \
        {params.work_directory}/OUTSIDER/FREQ_AFTER/tmp_MAPPING_POSTION_TE.sam


        samtools sort {params.work_directory}/OUTSIDER/FREQ_AFTER/tmp_MAPPING_POSTION_TE.sam > {params.work_directory}/OUTSIDER/FREQ_AFTER/tmp_MAPPING_POSTION_TE.sorted.bam
        samtools index {params.work_directory}/OUTSIDER/FREQ_AFTER/tmp_MAPPING_POSTION_TE.sorted.bam
        samtools calmd {params.work_directory}/OUTSIDER/FREQ_AFTER/tmp_MAPPING_POSTION_TE.sorted.bam {input.genome} > {params.work_directory}/OUTSIDER/FREQ_AFTER/tmp_MAPPING_POSTION_TE_MD.sorted.bam 2> {log}.err
        samtools view -b -h {params.work_directory}/OUTSIDER/FREQ_AFTER/tmp_MAPPING_POSTION_TE_MD.sorted.bam > {params.work_directory}/OUTSIDER/FREQ_AFTER/MAPPING_POSTION_TE_MD.sorted.bam
        samtools index {params.work_directory}/OUTSIDER/FREQ_AFTER/MAPPING_POSTION_TE_MD.sorted.bam

        # VARIANT CALLING 
        if [ {params.call_sv} = "svim" ]; then
            
            svim alignment --read_names \
                --insertion_sequences \
                --minimum_depth 1 {params.work_directory}/OUTSIDER/FREQ_AFTER \
                {params.work_directory}/OUTSIDER/FREQ_AFTER/MAPPING_POSTION_TE_MD.sorted.bam \
                {input.genome} 2> svim.log
        else
            version=`sniffles -h 2>&1 | grep Version | cut -d " " -f 2`

            ## version work
            if [ "$version" = "1.0.10" ]; then

                (bash ${{path_to_pipline}}/lib/bash/load.sh &) || echo
                run_cmd "sniffles --report_seq -s 1 -m {params.work_directory}/OUTSIDER/FREQ_AFTER/MAPPING_POSTION_TE_MD.sorted.bam -v {params.work_directory}/OUTSIDER/FREQ_AFTER/variants.vcf -n -1" "{log}" "SNIFFLES 1.0.10" "False";
                sh ${{path_to_pipline}}/lib/bash/end_load.sh;

            elif [ "$version" = "1.0.12" ]; then

                (bash ${{path_to_pipline}}/lib/bash/load.sh &) || echo
                run_cmd "sniffles --report-seq -s 1 -m {params.work_directory}/OUTSIDER/FREQ_AFTER/MAPPING_POSTION_TE_MD.sorted.bam -v {params.work_directory}/OUTSIDER/FREQ_AFTER/variants.vcf -n -1" "{log}" "SNIFFLES 1.0.12" "False";
                sh ${{path_to_pipline}}/lib/bash/end_load.sh;
            fi;

        fi;


        python3 ${{path_to_pipline}}/lib/python/get_seq_vcf.py {params.work_directory}/OUTSIDER/FREQ_AFTER/variants.vcf \
        {params.work_directory}/OUTSIDER/FREQ_AFTER/variants.fasta

        makeblastdb -in {input.fasta_TE} -dbtype nucl 2> {log}.err;
        blastn -db {input.fasta_TE} \
        -query {params.work_directory}/OUTSIDER/FREQ_AFTER/variants.fasta \
        -outfmt 6 \
        -out {params.work_directory}/OUTSIDER/FREQ_AFTER/variants.bln 2>> {log}.err;


        python3 ${{path_to_pipline}}/lib/python/parse_blast_main.py \
            {params.work_directory}/OUTSIDER/FREQ_AFTER/variants.bln \
            {input.fasta_TE} \
            {params.work_directory}/OUTSIDER/FREQ_AFTER/FILTER_BLAST_SEQUENCE_INDEL_vs_DBTE.csv -c {params.pars_bln_option}

        i=0;
        while read line; do
            
            if [ $i -ne 0 ]; then
                region=`echo $line | awk '{{print $2}}' | awk -F ":" '{{print $1":"$3"-"$3}}'`
                depth=`samtools depth {params.work_directory}/OUTSIDER/FREQ_AFTER/MAPPING_POSTION_TE_MD.sorted.bam -r $region`;
                NB_depth=`echo $depth | awk '{{print $3}}'`

                TE=`echo $line | awk '{{print $1}}'`
                info_TE=`echo $line | awk 'OFS="\t"{{print $1, $2}}'`
                RS=`echo $line | awk '{{print $2}}' | awk -F ":" '{{print $6}}'`

                if [ -n "$depth" ]; then
                    ###echo "$i : $info_TE : $depth : RS=$RS : NB_depth=$NB_depth"
                    printf "$depth\t$(($NB_depth-$RS))\t$RS\t%.4f\t$info_TE\\n" "$(((10**6 * $RS/$NB_depth) * 100))e-6" | tr "," "." >> {output.depth_te}
                else
                    printf "$depth\t$(($NB_depth-$RS))\t$RS\t%.4f\t${{info_TE}}|ERROR\\n" "0" | tr "," "." >> {output.depth_te}
                    message_fail "ERROR FOR ${{info_TE}} \\n ERROR GETTING DEPTH YOU NEED TO RECONSTRUCT YOUR BAM FILE\\n";
                fi;
            else
                printf "chrom\tposition\ttotal_depth\tdepth_empty_site\tread_support\tread_support_percent\tTE\tinfo_TE\\n"  > {output.depth_te}
            fi;
            
            i=$(($i+1));

        done < {params.work_directory}/OUTSIDER/FREQ_AFTER/FILTER_BLAST_SEQUENCE_INDEL_vs_DBTE.csv;

        ##
        rm -f {params.work_directory}/MAPPING_POSTION_TE.sam
        rm -f {params.work_directory}/OUTSIDER/FREQ_AFTER/tmp*
        rm -f {params.work_directory}/OUTSIDER/FREQ_AFTER/TE_POSITION_SIZE.txt
        #rm -fr {params.work_directory}/OUTSIDER/FREQ_AFTER

        """



rule FREQ_GLOBAL:
    input:  
        TE_INS   = config["DATA"]["WORK_DIRECTORY"].rstrip("/") + "/INSIDER/TE_DETECTION/INSERTION.csv",
        bam      = config["DATA"]["WORK_DIRECTORY"].rstrip("/") + "/OUTSIDER/MAPPING/SAMPLE_mapping_GENOME_MD.sorted.bam",

    output:
        DEPTH = config["DATA"]["WORK_DIRECTORY"].rstrip("/") + "/INSIDER/FREQ_GLOBAL/DEPTH_TE_INSIDER.csv",
        tmp   = temp(touch("tmp_snk/rule_tmp_FREQ_GLOBAL")),

    params:
        path_snk       = path_snk,
        work_directory = config["DATA"]["WORK_DIRECTORY"].rstrip("/"),

        env            = env,
        
        #COLOR 
        cmess          = bcolors.CYAN,
        cfail          = bcolors.FAIL,
        cend           = bcolors.END,
    log:
        config["DATA"]["WORK_DIRECTORY"].rstrip("/") + "/log/FREQ_GLOBAL",

    shell:
        """

        printf "\\n%s\\n\\n" "{params.cmess} [SNK]--[`date`] FREQ_GLOBAL {params.cend}"

        {params.env}
        path_to_pipline=`dirname {params.path_snk}`
        
        mkdir -p {params.work_directory}/OUTSIDER/MAPPING_TO_REF/

        cat {input.TE_INS} | cut -f 2 | \
        awk -v margin_flank=1000 -F ":" 'OFS="\t"{{split($6, a, "-"); print $5, a[1]-margin_flank, a[1]-margin_flank+1; print $5, a[2]+margin_flank, a[2]+margin_flank+1}}' > {params.work_directory}/OUTSIDER/MAPPING_TO_REF/FLANK_TE.bed

        cat {input.TE_INS} | cut -f 2 | \
        awk -v margin_flank=5 -F ":" 'OFS="\t"{{split($6, a, "-"); print $5, a[1]+margin_flank, a[1]+margin_flank+1; print $5, a[2]-margin_flank, a[2]-margin_flank+1}}' > {params.work_directory}/OUTSIDER/MAPPING_TO_REF/FLANK_TE_PASS2.bed

        samtools view -h -b {input.bam} -F 2048 -L {params.work_directory}/OUTSIDER/MAPPING_TO_REF/FLANK_TE.bed > {params.work_directory}/OUTSIDER/MAPPING_TO_REF/tmp_flank_TE_OUT.bam
        samtools index {params.work_directory}/OUTSIDER/MAPPING_TO_REF/tmp_flank_TE_OUT.bam

        samtools view -h {params.work_directory}/OUTSIDER/MAPPING_TO_REF/tmp_flank_TE_OUT.bam > {params.work_directory}/OUTSIDER/MAPPING_TO_REF/tmp_flank_TE_OUT.sam

        #INTERN TO TE
        # samtools view -h -b {params.work_directory}/OUTSIDER/MAPPING_TO_REF/tmp_flank_TE_OUT.bam -F 2048 -L {params.work_directory}/OUTSIDER/MAPPING_TO_REF/FLANK_TE_PASS2.bed > {params.work_directory}/OUTSIDER/MAPPING_TO_REF/tmp_flank_TE_IN.bam
        # samtools index {params.work_directory}/OUTSIDER/MAPPING_TO_REF/tmp_flank_TE_IN.bam

        awk 'NR>1 && OFS="\t"{{split($2, a, ":"); split(a[6], b, "-"); print a[5], b[1], b[2], $1"|"a[1]}}' \
        {input.TE_INS} > {params.work_directory}/OUTSIDER/MAPPING_TO_REF/INSERTION_TE.bed

        printf "chrom\tposition\ttotal_depth\tdepth_empty_site\tread_support\tread_support_percent\tTE\tinfo_TE\\n"  > {output.DEPTH}
        
        number_lines=`cat {params.work_directory}/OUTSIDER/MAPPING_TO_REF/INSERTION_TE.bed | wc -l`
        i=0;

        show_step="$i/$number_lines TE"
        number_of_char=`echo "$show_step" | wc -c`
        number_of_char=$(($number_of_char-1));
        printf "\b%.0s" `seq 1 $number_of_char`
        printf "$show_step";

        while read line; do
            chrom=`echo $line | awk '{{print $1}}'`
            start=`echo $line | awk '{{print $2}}'`
            end=`echo $line | awk '{{print $3}}'`
            info=`echo $line | awk '{{print $4}}'`

            ###echo "info : $info"
            TE=`echo $line | awk '{{print $4}}' | cut -d "|" -f 1`

            size_TE=$(($end-$start))

            ###echo "size_TE : $size_TE"

            echo $line | tr " " "\\t" | cut -f 1-3 > {params.work_directory}/OUTSIDER/MAPPING_TO_REF/tmp.bed

            ###cat {params.work_directory}/OUTSIDER/MAPPING_TO_REF/tmp.bed

            samtools view {params.work_directory}/OUTSIDER/MAPPING_TO_REF/tmp_flank_TE_OUT.bam -F 2048 -L {params.work_directory}/OUTSIDER/MAPPING_TO_REF/tmp.bed > {params.work_directory}/OUTSIDER/MAPPING_TO_REF/tmp_tmp_flank_TE_OUT.sam

            if test -s {params.work_directory}/OUTSIDER/MAPPING_TO_REF/tmp_tmp_flank_TE_OUT.sam; then
                NB_DEL=`cat {params.work_directory}/OUTSIDER/MAPPING_TO_REF/tmp_tmp_flank_TE_OUT.sam | cut -f 6 | grep "[0-9]*D" -o | tr -d "D" | awk -v size="$size_TE" -v marge="20" '($0 <= size+marge && $0 >= size) || ($0 >= size+marge && $0 <= size-1 )' | wc -l`

                rm -f {params.work_directory}/OUTSIDER/MAPPING_TO_REF/tmp_tmp_flank_TE_OUT.sam {params.work_directory}/OUTSIDER/MAPPING_TO_REF/tmp.bed

                ###echo "NB_DEL : $NB_DEL"#deletion
                
                depth_fk_left=`samtools depth {params.work_directory}/OUTSIDER/MAPPING_TO_REF/tmp_flank_TE_OUT.bam -r $chrom:$(($start-20))-$(($start-20)) | cut -f 3`;
                depth_fk_right=`samtools depth {params.work_directory}/OUTSIDER/MAPPING_TO_REF/tmp_flank_TE_OUT.bam -r $chrom:$(($end+20))-$(($end+20)) | cut -f 3`;

                if [ -n "$depth_fk_left" ] && [ -n "$depth_fk_right" ] ; then

                    depth_total_mean=$((($depth_fk_left+$depth_fk_right)/2));
                    ###echo "depth_total_mean : $depth_total_mean"
                    if [ $depth_total_mean -ne 0 ]; then
                        NB_TE=$(($depth_total_mean-$NB_DEL))

                        #echo "NB_TE : $NB_TE"

                        if [ -n "$depth_total_mean" ]; then
                            ###echo "$i : $info : $depth : RS=$RS : NB_depth=$NB_depth"
                            printf "$chrom\t$start\t$depth_total_mean\t$NB_DEL\t$NB_TE\t%.4f\t$TE\t$info\\n" "$(((10**6 * $NB_TE/$depth_total_mean) * 100))e-6" | tr "," "." >> {output.DEPTH}
                        else
                            printf "$chrom\t$start\t-1\t$NB_DEL\t-1\t%.4f\t$TE\tinfo|ERROR\\n" "0" | tr "," "." >> {output.DEPTH}
                            message_fail "ERROR FOR ${{info}} \\n ERROR GETTING DEPTH YOU NEED TO RECONSTRUCT YOUR BAM FILE\\n";
                        fi;
                    fi;
                fi;
            fi;
            i=$(($i+1));

            show_step="$i/$number_lines TE"
            number_of_char=`echo "$show_step" | wc -c`
            number_of_char=$(($number_of_char-1));
            printf "\b%.0s" `seq 1 $number_of_char`
            printf "$show_step";

        done < {params.work_directory}/OUTSIDER/MAPPING_TO_REF/INSERTION_TE.bed;
        echo

        rm -f {params.work_directory}/OUTSIDER/MAPPING_TO_REF/tmp*
        rm -f {params.work_directory}/OUTSIDER/MAPPING_TO_REF/FLANK_TE*

        """


rule DETECTION_TE :
    input:
        vcf      = config["DATA"]["WORK_DIRECTORY"].rstrip("/") + "/OUTSIDER/VARIANT_CALLING/SV.vcf",
        fasta_TE = config["DATA"]["TE_DB"],
        bam      = config["DATA"]["WORK_DIRECTORY"].rstrip("/") + "/OUTSIDER/MAPPING/SAMPLE_mapping_GENOME_MD.sorted.bam",

    output:
        snif_seqs = config["DATA"]["WORK_DIRECTORY"].rstrip("/") + "/OUTSIDER/VARIANT_CALLING/SEQUENCE_INDEL.fasta",
        bln       = config["DATA"]["WORK_DIRECTORY"].rstrip("/") + "/OUTSIDER/TE_DETECTION/BLAST_SEQUENCE_INDEL_vs_DBTE.bln",
        all_te    = config["DATA"]["WORK_DIRECTORY"].rstrip("/") + "/OUTSIDER/TE_DETECTION/FILTER_BLAST_SEQUENCE_INDEL_vs_DBTE.csv",
        depth_te  = config["DATA"]["WORK_DIRECTORY"].rstrip("/") + "/OUTSIDER/TE_DETECTION/DEPTH_TE.csv",
        bam       = config["DATA"]["WORK_DIRECTORY"].rstrip("/") + "/OUTSIDER/MAPPING/MAPPING_POSTION_TE.bam",

    params:
        path_snk       = path_snk,
        work_directory = config["DATA"]["WORK_DIRECTORY"].rstrip("/"),

        env            = env, #source environnement

        CHROM_KEEP      = config["PARAMS"]["OUTSIDER_VARIANT"]["TE_DETECTION"]["CHROM_KEEP"],
        pars_bln_option = config["PARAMS"]["OUTSIDER_VARIANT"]["PARS_BLN_OPTION"],

        #COLORS
        cfail          = bcolors.FAIL,
        cmess          = bcolors.CYAN,
        cend           = bcolors.END,

    log:
        blastn = config["DATA"]["WORK_DIRECTORY"].rstrip("/") + "/log/DETECTION_TE"


    shell:
        """
        {params.env}
        printf "%s\\n" "{params.cmess} [SNK]--[`date`] DETECTION TE [^-^] {params.cend}"

        path_to_pipline=`dirname {params.path_snk}`

        mkdir -p {params.work_directory}/OUTSIDER/TE_DETECTION/

        #** GET SEQUENCE REPORT **#
        printf "%s\\n" "{params.cmess} [SNK]--[`date`] GET SEQUENCE VARIANT [^-^] {params.cend}"
        python3 ${{path_to_pipline}}/lib/python/get_seq_vcf.py -m 150 {input.vcf} {output.snif_seqs} -c {params.CHROM_KEEP} ;
        test -s {output.snif_seqs} || (message_fail "ERROR NO SEQUENCE SV FOUND" && exit 1)

        #cp {output.snif_seqs} {params.work_directory}/tmp_seq.fasta

        printf "%s\\n" "{params.cmess} [SNK]--[`date`] BLAST SV TO TE [^-^] {params.cend}"
        
        #** BLAST SEQUENCE VCF on DATABASE TE **#
        makeblastdb -in {input.fasta_TE} -dbtype nucl 2> {log.blastn}.err;
        blastn -db {input.fasta_TE} -query {output.snif_seqs} -outfmt 6 -out {output.bln} 2>> {log.blastn}.err;
        
        printf "%s\\n" "{params.cmess} [SNK]--[`date`] BLAST DONE CHECK logfile => {log.blastn} {params.cend}"

        #cp {output.bln} {params.work_directory}/tmp_blast.bln

        printf "%s\\n" "{params.cmess} [SNK]--[`date`] FILTER TE BLAST [^-^] {params.cend}"
        
        
        #** FILTER TE BLAST **#
        python3 ${{path_to_pipline}}/lib/python/parse_blast_main.py {output.bln} \
        {input.fasta_TE} {output.all_te} -c \
        --combine_name {params.work_directory}/OUTSIDER/TE_DETECTION/COMBINE_TE.csv {params.pars_bln_option};

        samtools index {input.bam} #2> {log}.err

        printf "%s\\n" "{params.cmess} [SNK]--[`date`] CALCUL FREQUENCE TE [^-^] {params.cend}"
        
        
        #** CALCUL FREQUENCE **#
        number_lines=`cat {output.all_te} | wc -l`
        i=0;

        show_step="$i/$number_lines"
        number_of_char=`echo "$show_step" | wc -c`
        number_of_char=$(($number_of_char-1));
        printf "\b%.0s" `seq 1 $number_of_char`
        printf "$show_step";


        while read line; do
            
            if [ $i -ne 0 ]; then
                region=`echo $line | awk '{{print $2}}' | awk -F ":" '{{print $1":"$3"-"$3}}'`
                depth=`samtools depth {input.bam} -r $region`;
                NB_depth=`echo $depth | awk '{{print $3}}'`

                TE=`echo $line | awk '{{print $1}}'`
                info_TE=`echo $line | awk 'OFS="\t"{{print $1, $2}}'`
                RS=`echo $line | awk '{{print $2}}' | awk -F ":" '{{print $6}}'`

                if [ -n "$depth" ]; then
                    ###echo "$i : $info_TE : $depth : RS=$RS : NB_depth=$NB_depth"
                    printf "$depth\t$(($NB_depth-$RS))\t$RS\t%.4f\t$info_TE\\n" "$(((10**6 * $RS/$NB_depth) * 100))e-6" | tr "," "." >> {output.depth_te}
                else
                    printf "$depth\t$(($NB_depth-$RS))\t$RS\t%.4f\t${{info_TE}}|ERROR\n" "0" | tr "," "." >> {output.depth_te}
                    message_fail "ERROR FOR ${{info_TE}} \\n ERROR GETTING DEPTH YOU NEED TO RECONSTRUCT YOUR BAM FILE\\n";
                fi;
            else
                printf "chrom\tposition\ttotal_depth\tdepth_empty_site\tread_support\tread_support_percent\tTE\tinfo_TE\\n"  > {output.depth_te}
            fi;
            
            i=$(($i+1));

            show_step="$i/$number_lines"
            number_of_char=`echo "$show_step" | wc -c`
            number_of_char=$(($number_of_char-1));
            printf "\b%.0s" `seq 1 $number_of_char`
            printf "$show_step";

        done < {output.all_te};


        printf "%s\\n" "{params.cmess} [SNK]--[`date`] GET BAM TE [^-^] {params.cend}"
        
        #** GET BAM TE **#
        awk 'NR>1 {{print $2":"$1}}' {output.all_te} | awk -v size="15" -F ":" 'OFS="\t"{{print $1, $3-size, $3+size, $5":"$9}}' > {params.work_directory}/OUTSIDER/TE_DETECTION/tmp_POSITION_START_TE.bed
        samtools view -h -b {input.bam} -L {params.work_directory}/OUTSIDER/TE_DETECTION/tmp_POSITION_START_TE.bed > {output.bam}

        rm -f {params.work_directory}/OUTSIDER/TE_DETECTION/tmp_POSITION_START_TE.bed
        

        awk 'NR>1 {{print $2":"$1}}' {output.all_te} | awk -F ":" 'OFS="\t"{{print $1, $3, $3+1, $5":"$9, $8}}' > {params.work_directory}/OUTSIDER/TE_DETECTION/POSITION_START_TE.bed


        #** REMOVE **#
        #rm -f {params.work_directory}/OUTSIDER/TE_DETECTION/POSITION_START_TE.bed;
        """



rule sniffles :
    input:
        config["DATA"]["WORK_DIRECTORY"].rstrip("/") + "/OUTSIDER/MAPPING/SAMPLE_mapping_GENOME_MD.sorted.bam",

    output:
        config["DATA"]["WORK_DIRECTORY"].rstrip("/") + "/OUTSIDER/VARIANT_CALLING/SV.vcf", 
        
    params:
        path_snk       = path_snk,
        work_directory = config["DATA"]["WORK_DIRECTORY"].rstrip("/"),

        env            = env, #source environnement

        cfail          = bcolors.FAIL,
        cmess          = bcolors.CYAN,
        cend           = bcolors.END,

    log:
        config["DATA"]["WORK_DIRECTORY"].rstrip("/") + "/log/sniffles",

    shell:
        """
        {params.env}
        path_to_pipline=`dirname {params.path_snk}`

        mkdir -p {params.work_directory}/OUTSIDER/VARIANT_CALLING/

        printf "%s\\n" "{params.cmess} [SNK]--[`date`] SNIFFLES [^-^] {params.cend}"

        samtools index {input} 2> {log}.err

        #sniffles --report-seq -s 1 -m {input} -v {output} -n -1 2> {log}.err;
        
        version=`sniffles -h 2>&1 | grep Version | cut -d " " -f 2`

        ## version work
        if [ "$version" = "1.0.10" ]; then

            (bash ${{path_to_pipline}}/lib/bash/load.sh &) || echo
            run_cmd "sniffles --report_seq -s 1 -m {input} -v {output} -n -1" "{log}" "SNIFFLES 1.0.10" "False";
            sh ${{path_to_pipline}}/lib/bash/end_load.sh;

        elif [ "$version" = "1.0.12" ]; then

            (bash ${{path_to_pipline}}/lib/bash/load.sh &) || echo
            run_cmd "sniffles --report-seq -s 1 -m {input} -v {output} -n -1" "{log}" "SNIFFLES 1.0.12" "False";
            sh ${{path_to_pipline}}/lib/bash/end_load.sh;

        else
            message_fail "[SNK] -- [`date`] -- [ERROR] version $version YOU HAVE NOT THE GOOD VERSION OF SNIFFLES, PLEASE GET VERSION 1.0.10 or 1.0.12"
            exit 2
        fi;


        """

rule samtools :
    input:
        sam    = config["DATA"]["WORK_DIRECTORY"].rstrip("/") + "/OUTSIDER/MAPPING/SAMPLE_mapping_GENOME.sam",
        genome = config["DATA"]["GENOME"],

    output:
        config["DATA"]["WORK_DIRECTORY"].rstrip("/") + "/OUTSIDER/MAPPING/SAMPLE_mapping_GENOME_MD.sorted.bam",
        
    params:
        #DATA
        work_directory = config["DATA"]["WORK_DIRECTORY"].rstrip("/"),
        env            = env, #source environnement
        
        #PARAMS
        preset_view    = config["PARAMS"]["OUTSIDER_VARIANT"]["SAMTOOLS_VIEW"]["PRESET_OPTION"],
        preset_sort    = config["PARAMS"]["OUTSIDER_VARIANT"]["SAMTOOLS_SORT"]["PRESET_OPTION"],
        preset_callmd  = config["PARAMS"]["OUTSIDER_VARIANT"]["SAMTOOLS_CALLMD"]["PRESET_OPTION"],
        
        #COLORS
        cmess          = bcolors.CYAN,
        cfail          = bcolors.FAIL,
        cend           = bcolors.END,

    log:
        config["DATA"]["WORK_DIRECTORY"].rstrip("/") + "/log/samtools",

    shell:
        """
        {params.env}
        printf "\\n%s\\n\\n" "{params.cmess} [SNK]--[`date`] SAMTOOLS [^-^] {params.cend}"

        mkdir -p {params.work_directory}/OUTSIDER/MAPPING/

        echo "---view---" | tee {log}.out
        #samtools view -h {params.preset_view} -b {input.sam} > {input.sam}.bam 2>> {log}.err;
        run_cmd "samtools view -h {params.preset_view} -b {input.sam} | tee {input.sam}.bam" "{log}" "SAMTOOLS_VIEW" "False";

        rm -f {log}.out

        echo "---sort---" | tee -a {log}.out
        #samtools sort {params.preset_sort} {input.sam}.bam -o {input.sam}.sorted.bam 2>> {log}.err;
        run_cmd "samtools sort {params.preset_sort} {input.sam}.bam -o {input.sam}.sorted.bam" "{log}" "SAMTOOLS_SORT" "False";

        echo "---calmd---" | tee -a {log}.out
        #samtools calmd {params.preset_callmd} -b {input.sam}.sorted.bam {input.genome} > {output} 2>> {log}.err; #CALL MD for sniffles
        run_cmd "samtools calmd {params.preset_callmd} -b {input.sam}.sorted.bam {input.genome} | tee {output}" "{log}" "SAMTOOLS_CALLMD" "False";#CALL MD for sniffles

        rm -f {input.sam} \
        {input.sam}.bam \
        {input.sam}.sorted.bam*;

        """


rule mapping :
    input:  
        read   = config["DATA"]["SAMPLE"],
        genome = config["DATA"]["GENOME"],

    output:
        config["DATA"]["WORK_DIRECTORY"].rstrip("/") + "/OUTSIDER/MAPPING/SAMPLE_mapping_GENOME.sam",
    
    params:
        path_snk       = path_snk,
        work_directory = config["DATA"]["WORK_DIRECTORY"].rstrip("/"),
        config         = json.dumps(config),

        preset         = config["PARAMS"]["OUTSIDER_VARIANT"]["MINIMAP2"]["PRESET_OPTION"] if config["PARAMS"]["OUTSIDER_VARIANT"]["MINIMAP2"]["PRESET_OPTION"] != "" else "map-ont",
        option         = config["PARAMS"]["OUTSIDER_VARIANT"]["MINIMAP2"]["OPTION"],

        env            = env, #source environnement


        #COLOR 
        cmess          = bcolors.CYAN,
        cfail          = bcolors.FAIL,
        cend           = bcolors.END,
    log:
        config["DATA"]["WORK_DIRECTORY"].rstrip("/") + "/log/minimap2"

    shell:
        """
        {params.env};
        path_to_pipline=`dirname {params.path_snk}`

        mkdir -p {params.work_directory}/OUTSIDER/MAPPING/

        printf "\\n%s\\n\\n" "{params.cmess} [SNK]--[`date`] MINIMAP2 MAPPING {params.cend}"
        
        #minimap2 -x  {params.preset} -d {input.genome}.mmi {input.genome} 2> {log}.err;
        run_cmd "minimap2 -x  {params.preset} -d {input.genome}.mmi {input.genome}" "{log}" "MINIMAP2_INDEX" "False" ;

        #minimap2 -ax {params.preset} {params.option} {input.genome} {input.read} > {output} 2>> {log}.err;
        
        (bash ${{path_to_pipline}}/lib/bash/load.sh &) || echo
        run_cmd "minimap2 -ax {params.preset} {params.option} {input.genome} {input.read} | tee {output}" "{log}" "MINIMAP2" "False"; 
        sh ${{path_to_pipline}}/lib/bash/end_load.sh;

        rm -f {log}.out

        """

