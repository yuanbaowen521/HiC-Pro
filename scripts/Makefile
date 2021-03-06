## MAKEFILE FOR Hi-C PROCESSING
## Nicolas Servant

## DO NOT EDIT THE REST OF THIS FILE!!

## special characters
comma := ,
space :=
space +=
slash := |
tick := -
undsc := _

all : init mapping proc_hic build_contact_maps rmsam

all_qsub : init mapping proc_hic

init : configure 

mapping: bowtie_global bowtie_local bowtie_combine mapping_stat

proc_hic : bowtie_pairing mapped_2hic_fragments

## Per sample
build_contact_maps: merge_valid_interactions plots build_raw_maps ice_norm 

######################################
## System
##
######################################
config_check:
ifndef CONFIG_FILE
	$(error CONFIG_FILE is not defined)
else		
include $(CONFIG_FILE)
endif
ifndef CONFIG_SYS
	$(error CONFIG_SYS is not defined)
else		
include $(CONFIG_SYS)
endif



make_torque_script: config_check init
	@$(SCRIPTS)/make_torque_script.sh -c $(CONFIG_FILE)

rmsam: config_check 
ifdef BOWTIE2_OUTPUT_DIR
	@/bin/rm -f $(BOWTIE2_OUTPUT_DIR)/*/*/*.sam
endif

clean: 
ifdef LOGS_DIR
	@/bin/rm -f $(LOGS_DIR)/*
endif
	@/bin/rm -rf $(BOWTIE2_OUTPUT_DIR) $(MAPC_OUTPUT)

debug: config_check
	@echo "RAW_DIR="$(RAW_DIR)
	@echo "FASTQ_FILE="$(READSFILE_FQ)
	@echo "RES_FILE="$(RES_FILE_NAME)
	@echo "RES_FILE_OBJ="$(RES_FILE_NAME_OBJ)

######################################
## Configure outputs
##
######################################

## Create output folders
configure:  config_check
	@mkdir -p $(BOWTIE2_OUTPUT_DIR)
	@mkdir -p $(MAPC_OUTPUT)
	@mkdir -p $(TMP_DIR)
	@mkdir -p $(LOGS_DIR)

######################################
## Bowtie2 Global Alignment
##
######################################

## Global Alignement
bowtie_global:  config_check
	@echo "--------------------------------------------" 
	@date 
	@echo "Bowtie2 global alignment ..." 
	$(SCRIPTS)/bowtie_wrap.sh -c $(CONFIG_FILE) -u >> $(LOGFILE)

######################################
##  Bowtie2 Local Alignment
##
######################################

## Local Alignement
bowtie_local:  config_check
	@echo "--------------------------------------------" 
	@date 
	@echo "Bowtie2 local alignment ..." 
	$(SCRIPTS)/bowtie_wrap.sh -c $(CONFIG_FILE) -l >> $(LOGFILE)

######################################
## Merge Bowtie2 local and global mapping
## 
######################################

## Merge global and local alignment in a single file
bowtie_combine:  config_check
	@echo "--------------------------------------------" 
	@date 
	@echo "Combine both alignment ..."
	$(SCRIPTS)/bowtie_combine.sh -c $(CONFIG_FILE) >> $(LOGFILE)

## Compute mapping statistics
mapping_stat:  config_check
	@echo "--------------------------------------------" 
	@date 
	@echo "Bowtie2 mapping statistics for R1 and R2 tags ..." 
	$(SCRIPTS)/mapping_stat.sh -c $(CONFIG_FILE) >> $(LOGFILE)

plots:
	@echo "--------------------------------------------" 
	@date 
	@echo "Make plots per sample ..."
	$(SCRIPTS)/make_plots.sh -c $(CONFIG_FILE) >> $(LOGFILE)


######################################
## Hi-C processing 
##
######################################

## Pairing of R1 and R2 mates and reads filtering
bowtie_pairing:  config_check
	@echo "--------------------------------------------"
	@date 
	@echo "Pairing of R1 and R2 tags ..." 
	$(SCRIPTS)/bowtie_pairing.sh -c $(CONFIG_FILE) >> $(LOGFILE)

## Assign alignments to regions segmented by HindIII sites
mapped_2hic_fragments:  config_check
	@echo "--------------------------------------------"
	@date 
	@echo "Assign alignments to HindIII sites ..." 
	$(SCRIPTS)/mapped_2hic_fragments.sh -c $(CONFIG_FILE) >> $(LOGFILE)

## Combine multiple BAM files from the same sample, and remove duplicates
merge_valid_interactions:  config_check
	@echo "--------------------------------------------" 
	@date 
	@echo "Merge multiple files from the same sample ..." 
	$(SCRIPTS)/merge_valid_interactions.sh -c $(CONFIG_FILE) >> $(LOGFILE)

build_raw_maps:  config_check
	@echo "--------------------------------------------" 
	@date 
	@echo "Generate binned matrix files ..." 
	$(SCRIPTS)/build_raw_maps.sh -c $(CONFIG_FILE)

######################################
## Normalization
##
######################################

## Apply ICE normalization
ice_norm:
	@echo "--------------------------------------------" 
	@date 
	@echo "Run ICE Normalization ..." 
	$(SCRIPTS)/ice_norm.sh -c $(CONFIG_FILE) >> $(LOGFILE) # 2> $(LOGS_DIR)/normICE.log

