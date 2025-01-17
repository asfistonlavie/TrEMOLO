import os
import sys
import argparse
import subprocess
from random import randrange

parser = argparse.ArgumentParser(description="build snakemake file")

#MAIN ARGS
parser.add_argument("name_instruction", type=str,
                    help="file instruction_file snakemake file")

parser.add_argument("name_file_rules", type=str,
                    help="file contains a list of rules (of snakemake file)")

parser.add_argument("name_out", type=str,
                    help="name of output snakemake file ")

parser.add_argument("-t", "--name_template", type=str, help="template file contain additionnel instruction file python for snakemake file")
parser.add_argument("-n", "--name_ID", type=str, help="put ID depending to the name")

args = parser.parse_args()

#ARGS INIT
name_instruction = args.name_instruction
name_file_rules  = args.name_file_rules
name_template    = args.name_template
name_out         = args.name_out
work             = ""
if args.name_ID == None:
    ID = randrange(200)
else:
    ID = os.path.basename(args.name_ID.rstrip("/"))
    work = args.name_ID.rstrip("/").replace("/", "\/") + "\/"

instruction_file = open(args.name_instruction, "r")
instructions     = instruction_file.readline().replace(" ", "").strip().split(">")

list_name_rule   = [i.split(":")[0] for i in instructions]

print("[" + sys.argv[0] + "] LIST RULES : ", " -> ".join(instructions))
os.system("rm -f " + name_out)


if name_template:
    os.system("cat " + name_template + " > " + name_out)


def cmd(cmd):
    proc = subprocess.Popen([cmd], stdout=subprocess.PIPE, shell=True)
    (out, err) = proc.communicate()
    return str(out.decode("utf-8")).split("\\n")


nb_line_file_rules = cmd("wc -l " + name_file_rules + " | cut -d \" \" -f 1")[0]



for i, instruct in enumerate(instructions[::-1]):
    #os.system("rm -f tmpo_TrEMOLO"+str(i)+".snk")
    name_rule = instruct.split(":")[0]

    os.system("grep -w \"rule " + str(name_rule) + "\" " + name_file_rules + " -A " + str(int(nb_line_file_rules)) + " | grep \"^#END " + name_rule + "$\" -B " + str(int(nb_line_file_rules)) + " | grep -v \"^#END\" > tmpo_TrEMOLO"+str(i)+".snk")
    
    if len(instruct.split(":")) == 1  :
        if i == len(instructions) - 1 :
            os.system("sed -i '/input_link=\[\],/d' tmpo_TrEMOLO" + str(i) + ".snk")
            os.system("sed -i 's/output_link=\[\],/temp(touch(\"" + work + "tmp_TrEMOLO_output_rule\/rule_tmp_" + name_rule + "_" + str(ID) + "\")),/g' tmpo_TrEMOLO" + str(i) + ".snk")
        else  :
            os.system("sed -i 's/output_link=\[\],/temp(touch(\"" + work + "tmp_TrEMOLO_output_rule\/rule_tmp_" + name_rule + "_" + str(ID) + "\")),/g' tmpo_TrEMOLO" + str(i) + ".snk")
            os.system("sed -i 's/input_link=\[\],/cout=[\"" + work + "tmp_TrEMOLO_output_rule\/rule_tmp_" + list_name_rule[::-1][i+1] + "_" + str(ID) + "\"],/g' tmpo_TrEMOLO"+ str(i) + ".snk")
    #suppression des input et output improviser
    elif len(instruct.split(":")) > 1 and instruct.split(":")[1] == "N":
        os.system("sed -i '/input_link=\[.*\],/d' tmpo_TrEMOLO"+str(i)+".snk")
        os.system("sed -i '/output_link=\[.*\],/d' tmpo_TrEMOLO" + str(i) + ".snk")
    elif len(instruct.split(":")) > 1 and instruct.split(":")[1] == "NI":
        os.system("sed -i '/input_link=\[.*\],/d' tmpo_TrEMOLO"+str(i)+".snk")
        os.system("sed -i 's/output_link=\[\],/temp(touch(\"" + work + "tmp_TrEMOLO_output_rule\/rule_tmp_" + name_rule + "_" + str(ID) + "\")),/g' tmpo_TrEMOLO" + str(i) + ".snk")
    elif len(instruct.split(":")) > 1 and instruct.split(":")[1] == "NO":
        os.system("sed -i '/output_link=\[.*\],/d' tmpo_TrEMOLO" + str(i) + ".snk")
        os.system("sed -i 's/input_link=\[\],/cout=[\"" + work + "tmp_TrEMOLO_output_rule\/rule_tmp_" + list_name_rule[::-1][i+1] + "_" + str(ID) + "\"],/g' tmpo_TrEMOLO"+ str(i) + ".snk")

    os.system("sed -i 's/step=0,/step=" + str(len(instructions)-i) + ",/g' tmpo_TrEMOLO"+ str(i) + ".snk")

    #print("grep \"rule " + str(name_rule) +"\" " + name_file_rules + " -A " + str(nb_line_file_rules) + " | grep \"^#END " + name_rule + "$\" -B 100000000 | grep -v \"^#END\" >> " + name_out)
    #os.system("grep \"rule "+ str(name_rule) +"\" list_rules.txt -A " + str(nb_line_file_rules) + " | grep \"^#END " + name_rule + "$\" -B 10000000 | grep -v \"^#END\" >> tmp.snk")
    os.system("cat tmpo_TrEMOLO"+str(i)+".snk >> " + name_out)
    os.system("rm -f tmpo_TrEMOLO*.snk")





