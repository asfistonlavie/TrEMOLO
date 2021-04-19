
import os
import sys
import pandas as pd
import subprocess
import argparse

parser = argparse.ArgumentParser(description="Insere des sequence de variant rares dans un genome")

#MAIN ARGS
parser.add_argument("bed_file", type=str,
                    help="bed file to parse")
parser.add_argument("genome_file", type=str,
                    help="genome fasta file to parse")
parser.add_argument("TE_seq_file", type=str,
                    help="fasta file TE sequence")


parser.add_argument("-ob", "--out_bed_file", type=str,
                    help="name output bed file", default="true_bed.bed")
parser.add_argument("-og", "--out_genome_file", type=str,
                    help="name output genome file", default="genome.out.fasta")


args = parser.parse_args()

# name_bed_file    = sys.argv[1]
# name_genome_file = sys.argv[2]
# seq_TE_file      = sys.argv[3]

df_bed         = pd.read_csv(args.bed_file, sep="\t", header=None)
df_bed.columns = ["chrom", "start", "end", "name"]

df_bed = df_bed.sort_values(by=["chrom", "start"])

dico   = {"chrom":[], "start":[], "end":[], "name":[]}

#print(df_bed.head())

def find_seq_in_fa(motif, file, options=""):
    proc = subprocess.Popen(["grep " + options + " " + motif + " " + file], stdout=subprocess.PIPE, shell=True)
    (out, err) = proc.communicate()
    #print(str(out))
    return out.decode('ascii').split("\n")

#True bed
for chrom in df_bed["chrom"].unique():
    df_tmp_chrom = df_bed[df_bed["chrom"] == chrom]
    df_tmp_chrom = df_tmp_chrom.sort_values(by=["start"])
    decalage = 0
    for i, v in enumerate(df_tmp_chrom.values):
        start = df_tmp_chrom["start"].values[i]
        end   = df_tmp_chrom["end"].values[i]
        name  = df_tmp_chrom["name"].values[i]
        size  = abs(int(end) - int(start))
        
        #reposition start, end
        start += decalage
        end   += decalage

        dico["chrom"].append(chrom)
        dico["start"].append(start)
        dico["end"].append(end)
        dico["name"].append(name)

        #new decalage
        decalage += size


df_new_bed = pd.DataFrame(dico)
df_new_bed = df_new_bed.sort_values(by=["chrom", "start"])

#print(df_new_bed.head())
df_new_bed.to_csv(args.out_bed_file, sep="\t", index=None, header=None)

genome_file_out = open(args.out_genome_file, "w")

#Integration
genome_file = open(args.genome_file, "r")

line = genome_file.readline()
while line :
    if line[0] ==   ">" :

        chrom_g      = line[1:].strip()
        sequence     = genome_file.readline()
        df_tmp_chrom = df_new_bed[df_new_bed["chrom"] == chrom_g]
        for i, v in enumerate(df_tmp_chrom.values):
            start = df_tmp_chrom["start"].values[i]
            end   = df_tmp_chrom["end"].values[i]
            name  = df_tmp_chrom["name"].values[i]
            ID    = name.split(":")[1]
            #ID    = name.split(":")[1]
            #print("name:", name)
            out_line = find_seq_in_fa(":"+ID+":[0-9]*:[IP]", args.TE_seq_file, "-A 1")
            #ET      = str(out_line[-2]).strip().replace("N", "A")
            ET       = str(out_line[-2]).strip()
            if end != start + len(ET):
                print("ERROR : Calcul bedfile dist TE", ID, name)
                exit(1)

            #print("ET", ET[:5], len(ET), start, end)
            sequence = sequence[:start] + ET + sequence[start:]
            #new_ET   = sequence[start:end]
            #print("+++" + name + " : "  + ID + "\n" + new_ET)

        #print("Chrom:" + chrom_g + "  \n")
        genome_file_out.write(">" + chrom_g + "\n")
        genome_file_out.write(sequence.strip() + "\n")
        #print(sequence)

    line = genome_file.readline()


genome_file.close()

#csv to ned VRARE
#awk 'NR>1 {split($2, a, ":"); print a[1], a[3], a[3]+($9-$8), $1":"a[5]}' G73vsG73LR_cnTE_ALL_ET.csv | sed 's/ /\t/g' > G73vsG73LR_cnTE_ALL_ET.bed