Bootstrap: docker
From: ubuntu:20.04
%help
    Container for TrEmolo v2.0
    https://github.com/DrosophilaGenomeEvolution/TrEMOLO
    Includes 
        Blast 2.2+
        Bedtools2
        RaGOO v1.1 
        Assemblytics
        Snakemake 5.5.2+
        Minimap2 2.16+
        Samtools 1.10+
        Sniffles 1.0.10+
        SVIM 1.4.2+
        Flye 2.8+
        WTDBG 2.5+
        libfontconfig1-dev 
        Python libs
            Biopython
            Pandas
            Numpy
            pylab
            intervaltree 
        R libs
            ggplot2
            RColorBrewer
            extrafont
            rmarkdown 
            kableExtra
            dplyr
            reshape2 
            forcats 
            ggthemes 
            rjson 
            viridisLite 
            viridis 
            bookdown 
            knitr 
        Perl v5.26.2
        
%labels
    VERSION "TrEMOLO v2.0"
    Maintainer Francois Sabot <francois.sabot@ird.fr>
    March, 2021

%post
    # faster apt downloads
    export DEBIAN_FRONTEND=noninteractive
    export LC_ALL=C
    (
        . /etc/os-release
        cat << _EOF_ > mirror.txt
deb mirror://mirrors.ubuntu.com/mirrors.txt ${UBUNTU_CODENAME} main restricted universe multiverse
deb mirror://mirrors.ubuntu.com/mirrors.txt ${UBUNTU_CODENAME}-updates main restricted universe multiverse
deb mirror://mirrors.ubuntu.com/mirrors.txt ${UBUNTU_CODENAME}-backports main restricted universe multiverse
deb mirror://mirrors.ubuntu.com/mirrors.txt ${UBUNTU_CODENAME}-security main restricted universe multiverse

_EOF_
        mv /etc/apt/sources.list /etc/apt/sources.list.bak
        cat mirror.txt /etc/apt/sources.list.bak > /etc/apt/sources.list
    )

    # apt dependencies
    apt update
    apt install -y \
    	apt-utils \
        autoconf \
        automake \
        cmake \
        gcc \
        build-essential \
        software-properties-common \
        tar \
        unzip \
        wget \
        zlib1g-dev \
        sudo \
        git-core \
        locales \
        python3-pip \
        ncbi-blast+ \
        samtools \
        bedtools \
        minimap2 \
        sniffles \
        snakemake \
        assemblytics \
        r-base \
        perl \
        libfontconfig1-dev


    # R dependencies
    R --slave -e 'install.packages("RColorBrewer")'
    R --slave -e 'install.packages("ggplot2")'
    R --slave -e 'install.packages("extrafont")'
    R --slave -e 'install.packages("rmarkdown")'
    R --slave -e 'install.packages("kableExtra")'
    R --slave -e 'install.packages("dplyr")'
    R --slave -e 'install.packages("reshape2")'
    R --slave -e 'install.packages("forcats")'
    R --slave -e 'install.packages("ggthemes")'
    R --slave -e 'install.packages("rjson")'
    R --slave -e 'install.packages("viridisLite")'
    R --slave -e 'install.packages("viridis")'
    R --slave -e 'install.packages("bookdown")'
    R --slave -e 'install.packages("knitr")'
    
    #Python libs
    python3 -m pip install biopython pandas numpy matplotlib svim intervaltree scipy svim
       
    # build variables
    export TOOLDIR=/opt/tools

	#Preparing Directories
	mkdir -p $TOOLDIR

    
    #installing Flye 2.8+
	cd $TOOLDIR
    git clone https://github.com/fenderglass/Flye
    cd Flye
    python3 setup.py install

    
    #install RaGOO
    cd $TOOLDIR
    git clone https://github.com/malonge/RaGOO.git
    cd RaGOO
    python3 setup.py install
    
    #install WTDBG2
    cd $TOOLDIR
    git clone https://github.com/ruanjue/wtdbg2
    cd wtdbg2
    make
    

	
	#install TrEMOLO
	cd $TOOLDIR
	git clone https://github.com/DrosophilaGenomeEvolution/TrEMOLO.git
    
%environment
    export PATH=$TOOLDIR/wtdbg2/:$TOOLDIR/RaGOO/:$TOOLDIR/Flye/:$TOOLDIR/TrEMOLO/:$PATH

	
%runscript
    exec "$@"