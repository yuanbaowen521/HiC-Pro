##
## hic.inc.sh
##
## Eric Viara for Institut Curie, copyright (c) May 2014
## Modified Nicolas Servant Octobre 29 
##

###########################
## Load Configuration
###########################
#function error_handler() {
#  echo "Error occurred in script at line: ${1}."
#  echo "Line exited with status: ${2}"
#}

#trap 'error_handler ${LINENO} $?' ERR
set -o pipefail  # trace ERR through pipes
set -o errexit   ## set -e : exit the script if any statement returns a non-true return value

CURRENT_PATH=`dirname $0`

tmpfile1=/tmp/hic1.$$
tmpfile2=/tmp/hic2.$$
tmpmkfile=/tmp/hicmk.$$
trap "rm -f $tmpfile1 $tmpfile2 $tmpmkfile" 0 1 2 3

abspath() {
    [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}

filter_config()
{
    sed -e 's/#.*//' | egrep '^[ \t]*[a-zA-Z_][a-zA-Z0-9_]*[ \t]*:?=' | sed -e 's/[ \t]*:=[ \t]*/ :=/' -e 's/[ \t][^:]*=[ \t]*/ =/' -e 's/\([^ \t]*\)=/\1 =/' | sort -u -k 1b,1
}

read_config()
{
    local conf=$1
    cat $conf > $tmpmkfile
    echo "_dummy_target_:" >> $tmpmkfile
    make -f $tmpmkfile -p -n | filter_config > $tmpfile1
    cat $conf | filter_config > $tmpfile2

    eval "$(join $tmpfile1 $tmpfile2 | awk -F' =' '{printf("%s=\"%s\"; export %s;\n", $1, $2, $1)}')"

    
    ## Define BOWTIE outputs
    BOWTIE2_IDX=${BOWTIE2_IDX_PATH}/${REFERENCE_GENOME}; export BOWTIE2_IDX
    BOWTIE2_GLOBAL_OUTPUT_DIR=$BOWTIE2_OUTPUT_DIR/bwt2_global; export BOWTIE2_GLOBAL_OUTPUT_DIR
    BOWTIE2_LOCAL_OUTPUT_DIR=$BOWTIE2_OUTPUT_DIR/bwt2_local; export BOWTIE2_LOCAL_OUTPUT_DIR
    BOWTIE2_FINAL_OUTPUT_DIR=$BOWTIE2_OUTPUT_DIR/bwt2; export BOWTIE2_FINAL_OUTPUT_DIR
    
    ## Clean RAW_DIR variable
    RAW_DIR=$(echo $RAW_DIR | sed -e 's|^\./||')
}

## Load System config
SYS_CONF=$CURRENT_PATH/../config-system.txt
if [ -e "$SYS_CONF" ]; then
    read_config $SYS_CONF
else
    echo "Error - System config file not found"
    exit
fi

## load Hi-C config
if [ ! -z "$CONF" ]; then
    CONF=`abspath $CONF`
    if [ -e "$CONF" ]; then
	read_config $CONF
    else
	echo "Error - Hi-C config file '$CONF' not found"
	exit
    fi
fi

###########################
## Subroutine for scripts
###########################

die() { echo "Exit: $@" 1>&2 ; exit 1; }

exec_cmd()
{
    echo $*
    if [ -z "$DRY_RUN" ]; then
	eval "$@" ##|| die 'Error'
    fi
}

exec_ret()
{
    if [ -z "$DRY_RUN" ]; then
	eval "$@" ##|| die 'Error'
    fi
}

add_ext()
{
    local file=$1
    local ext=$2
    echo $file | grep "\${ext}$" > /dev/null
    if [ $? = 0 ]; then
	echo ${file}
    else
	echo ${file}${ext}
    fi
}

set_ext()
{
    local file=$1
    local ext=$2
    file=$(echo $file | sed -e "s/\.fastq$//")
    echo ${file}${ext}
}

add_fastq()
{
    add_ext $1 $2
}

get_R1()
{
    sed -e "s/${PAIR2_EXT}/${PAIR1_EXT}/"
}

get_R2()
{
    sed -e "s/${PAIR1_EXT}/${PAIR2_EXT}/"
}

get_pairs()
{
    sed -e "s/${PAIR1_EXT}//;s/${PAIR2_EXT}//"
}

filter_pairs()
{
	get_R1 | sort -u
}

#
# function called by get_hic_files, using "local" variables of get_hic_files
#

get_hic_files_build_list()
{
    local file=$idir/$(set_ext $fastq $ext)
    if [ ! -r $file ]; then
	echo "HiC get_hic_file: unreadable file: $file" >&2
    else
	if [ ! -z "$list" ]; then
	    list="$list
$file"
	else
	    list=$file
	fi
    fi
}

filter_rawdir()
{
    sed -e "s|\./${RAW_DIR}/||g" -e "s|${RAW_DIR}/||g"
}

get_hic_files()
{
    local idir=$1
    local ext=$2
    if [ ! -z "$FASTQFILE" ]; then
	if [ ! -z "$PBS_ARRAYID" ]; then
	    cat $FASTQFILE | filter_rawdir | filter_pairs | awk "NR == $PBS_ARRAYID {printf(\"%s/%s${ext}\n\", \"$idir\", gensub(\".fastq(.gz)*\", \"\", \$1));}"
	    return
	fi
	local list=
	for fastq in $(cat $FASTQFILE | filter_rawdir ); do
	    get_hic_files_build_list
	done
	echo "$list" | filter_pairs
    elif [ ! -z "$FASTQLIST" ]; then
	local list=
	for fastq in $(echo $FASTQLIST | filter_rawdir | sed -e 's/[,;]/ /g'); do
	    get_hic_files_build_list
	done
	echo "$list" | filter_pairs
    else
	find $idir \( -name \*${ext} -o -name \*${ext}.gz \) -follow -print | filter_pairs
    fi
}

get_sample_dir()
{
    local file=$1
    echo $(basename $(dirname ${file}))
}

get_fastq_for_bowtie_global()
{
    get_hic_files $RAW_DIR .fastq
}

get_fastq_for_bowtie_local()
{
    get_hic_files $BOWTIE2_GLOBAL_OUTPUT_DIR _${REFERENCE_GENOME}.bwt2glob.unmap.fastq
}

get_bam_for_pp()
{
    local=$1
    if [ "$local" = 1 ]; then
	get_hic_files $BOWTIE2_LOCAL_OUTPUT_DIR _${REFERENCE_GENOME}.bwt2glob.unmap_bwt2loc.bam
    else
	get_hic_files $BOWTIE2_GLOBAL_OUTPUT_DIR _${REFERENCE_GENOME}.bwt2glob.bam
    fi
}

get_global_aln_for_stats()
{
    get_hic_files ${BOWTIE2_GLOBAL_OUTPUT_DIR} _${REFERENCE_GENOME}.bwt2glob.bam
}

get_local_aln_for_stats()
{
    get_hic_files ${BOWTIE2_LOCAL_OUTPUT_DIR} _${REFERENCE_GENOME}.bwt2glob.unmap_bwt2loc.bam
}

get_aln_for_stats()
{
    local mode=$1
    if [ "$mode" = local ]; then
	get_local_aln_for_stats
    else
	get_global_aln_for_stats
    fi
}

get_stat_file()
{
    local mode=$1
    local file=$2
    local sample_dir=$(get_sample_dir ${file})
    local prefix=$(echo ${sample_dir}/$(basename $file) | sed -e 's/.bwt2glob.bam//')

    echo ${BOWTIE2_FINAL_OUTPUT_DIR}/$prefix.mapstat
}

get_sam_for_merge()
{
    get_hic_files ${BOWTIE2_FINAL_OUTPUT_DIR} _${REFERENCE_GENOME}.bwt2merged.bam   
}

get_sam_for_combine()
{
    get_hic_files ${BOWTIE2_GLOBAL_OUTPUT_DIR} _${REFERENCE_GENOME}.bwt2glob.bam   
}

get_files_for_overlap()
{
    get_hic_files ${BOWTIE2_FINAL_OUTPUT_DIR} _${REFERENCE_GENOME}.bwt2pairs.bam | get_R1 | sed -e "s/${PAIR1_EXT}//"
}
