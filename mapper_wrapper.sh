#!/bin/bash

MAGIC_BLAST_DIR=/home/ubuntu/bastian/ncbi-magicblast-1.3.0
WORK_DIR="$(pwd)"
programname=$0
version="0.1"

function usage {
	echo "usage:  $programname -d existingDBName [-e|-i taxList] [-m  magicBlastDir] [-o outDir] [-w workDir]"
	echo ""
	echo "  -d existingDBName	Reference database name - always required."
	echo "  -e taxList		Blacklist of taxonomy indicators - magicBlast will produce only [pieces] that are not included in these genomes."
	echo "  -i taxList		Whitelist of taxonomy indicators - magicBlast will produce only [pieces] that are included in these genomes."
	echo "  -m magicBlastDir	Specify the directory that contains the bin/magicblast - default is "$WORK_DIR
	echo "  -o outDir		Specify the directory for output. [What goes here?]"
	echo "  -w workDir		Specify the working directory to create the genome database in - default is the current directory."
	echo ""
	echo "  A whitelist or a blacklist can be provided, but not both.  If neither is provided, the reference database should already exist."
	echo "  Otherwise, the reference database will be created based on the whitelist/blacklist."
	documentTaxList

}

function documentTaxList {
	echo "  Blacklist and whitelist should be of the following format:"
	echo "  * Any one (or comma-separated list of multiple) of the following: "
	echo "  	all,archaea,bacteria,fungi,invertebrate,plant,protozoa,unknown,vertebrate_mammalian,vertebrate_other,viral"
	# document further options for taxList specifications (e.g. genus, taxID) that get added.
}


echo "Nanopore Mapper, version "$version

# Basic flag option validation
if [ $# -eq 0 ]; then     # Cannot be called meaningfully without flags
	usage
	exit 0
fi

while getopts ":d:e:i:m:o:w:" o; do
    case "${o}" in
        d)
	    BLAST_DB_NAME=${OPTARG}
	    ;;
	e)
            EXCLUDE_TAX=${OPTARG}
            ;;
        i)
            INCLUDE_TAX=${OPTARG}
            ;;
	m)
	    MAGIC_BLAST_DIR=${OPTARG}
	    ;;
	o)
	    OUTDIR=${OPTARG}
	    ;;
	w)
	    WORK_DIR=${OPTARG}
	    ;;
	:)
	   echo  "Invalid option: $OPTARG requires an argument"
	   usage
	   exit 0
	   ;;
        \?)			# When SRA IDs come in, this will break?
            usage
	    exit 0
            ;;
    esac
done
shift $((OPTIND-1))

# More sophisticated validation
if [ ! -d "$WORK_DIR" ]; then
  echo "$WORK_DIR" does not exist - exiting.
  exit 0
fi

if [ -z "$BLAST_DB_NAME" ]; then
  echo "Please supply the name of a reference database to use."
  exit 0
fi

if [ -n "$EXCLUDE_TAX" ] && [ -n "$INCLUDE_TAX" ]; then
  echo "Both a whitelist and blacklist were provided.  This is not currently supported."
  exit 0
fi

# Assumption: Uses nsd file existence as a proxy for the reference db having been created.
if [ -z "$EXCLUDE_TAX" ] && [ -z "$INCLUDE_TAX" ] && [ !  -f "$WORK_DIR"/"$BLAST_DB_NAME".nsd ]; then
  echo "When neither a whitelist nor a blacklist exists, the reference database must already exist.  This file does not exist: $WORK_DIR/$BLAST_DB_NAME.nsd"
  exit 0
fi
# End of Validation


# Download reference genomes and make database if necessary
if [ -n "$EXCLUDE_TAX" ] || [ -n "$INCLUDE_TAX" ]; then
  echo Combined fasta and db files will be in this working directory: "$WORK_DIR"
  echo Creating reference database "$BLAST_DB_NAME"

  # ncbi-genome-download will be a dependency
  # ncbi-genome-download does not actually support comma-separated list (even though it's supposed to)
  if [ -n "$EXCLUDE_TAX" ]; then
    ncbi-genome-download -F fasta "$EXCLUDE_TAX" 2>nanoporeMapperErrors.log
  fi
  if [ -n "$INCLUDE_TAX" ]; then
    ncbi-genome-download -F fasta "$INCLUDE_TAX" 2>nanoporeMapperErrors.log
  fi
  # for testing
#  ncbi-genome-download --format fasta --taxid 199310 bacteria
  wait

  # Exit if the genome download did not succeed. ncbi-genome-download does not return failure codes nor expose accessors for the list of valid inputs.
  if [ ! -d refseq ]; then
    echo Failed to download reference genome data.  See nanoporeMapperErrors.log
    exit 1
  fi

  # concat the FASTA files (currently only working with FASTA format)
  find refseq/ -name '*.fna.gz' | xargs zcat >>"$WORK_DIR"/"$BLAST_DB_NAME".fna
  # I couldn't get makeblastdb accept gzipped FASTAs, uncomment when we alter the makeblastdb command to accept gzip.
  # find refseq/ -name '*.fna.gz' | xargs cat >"$WORK_DIR"/"$BLAST_DB_NAME".fna.gz

  # build the magic-blast database
  "$MAGIC_BLAST_DIR"/bin/makeblastdb -in "$WORK_DIR"/"$BLAST_DB_NAME".fna -dbtype nucl -parse_seqids -out "$BLAST_DB_NAME"
else 
  echo Using existing reference database "$BLAST_DB_NAME"
fi
# magic-blast alignments

# filter magic-blasted reads

# use samtools to combine results

# output 
