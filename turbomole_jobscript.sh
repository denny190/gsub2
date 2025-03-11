#!/bin/bash

### Definition of variables for later use
CPU=1
MEMR=1
SCRATCH=1
WALLT=1

### Prompt for input file (e.g. myfile.inp or any other extension)
echo "[PROMPT] Input the name of your Turbomole input file (including extension):"
read -e filename_path_input

### Split the filename from its path
filename_input=$(basename "$filename_path_input")
filename_length=${#filename_input}

if [[ -d ${filename_path_input::-$filename_length} ]]; then
	DATADIR="${filename_path_input%/*}"
else
	DATADIR=$(pwd)
fi

EXTENSION="${filename_input##*.}"
FILENAME="${filename_input%.*}"

### Check if the input file exists
if test -f "$filename_path_input"; then
	echo "[INFO] Successfully located '$filename_input'."
else
	echo "[ERROR] Could not locate '$filename_input', terminating process."
	exit 1
fi

### (Optional) For Turbomole, checkpoint files are not standard.
### So we skip the old checkpoint file section.

### Generate the submit script for Turbomole
echo "[INFO] Generating Turbomole submit script."

echo "#!/bin/bash
# Ensure removal of temporary data when job ends or is terminated
trap 'cp -r \$SCRATCHDIR/${FILENAME}.log $DATADIR && clean_scratch' TERM

# Copy the input file from the working directory to the scratch space
cp $DATADIR/${FILENAME}.${EXTENSION} $SCRATCHDIR || exit 1

cd $SCRATCHDIR || exit 2

# Set parallelization for Turbomole if more than one processor is used
if [ ${CPU} -gt 1 ]; then
    export PARA_ARCH=MPI
    export PARNODES=${CPU}
fi

# Load the Turbomole module (adjust version if needed)
module add turbomole/6.0

# Execute the Turbomole job. The output will be saved as '${FILENAME}.log'
jobex -ri > ${FILENAME}.log

# Copy back the output log to the original directory
cp ${FILENAME}.log $DATADIR || export CLEAN_SCRATCH=false" > ${DATADIR}/${FILENAME}.sh

echo "[INFO] Submit script '${FILENAME}.sh' generated."

### Ask if the user wants to submit the job
read -r -p "[PROMPT] Do you wish to submit '$filename_input' for a Turbomole calculation? [Y/n]: " response
response=${response,,}  # convert to lowercase

if [[ $response =~ ^(yes|y| ) ]] || [[ -z $response ]]; then
	:
else
	echo "[EOF] EXITING."
	exit 0
fi

### Prompt if the user wants to modify allocated resources
echo -e "--------------------\n[INFO] Currently allocated resources:\nncpus=${CPU}\nmem=${MEMR}gb\nscratch_local=${SCRATCH}gb\nwalltime=${WALLT}:00:00\n--------------------"
read -r -p "[PROMPT] Do you wish to change any resource settings? [Y/n]: " response
response=${response,,}  # make lowercase

if [[ $response =~ ^(yes|y| ) ]] || [[ -z $response ]]; then
    read -p "[ncpus]= " CPU
    until [[ $CPU =~ ^[+]?[0-9]+$ ]]; do 
        echo "[ERROR] Please input a positive integer."
        read -p "[ncpus]= " CPU
    done

    read -p "[mem]= " MEMR
    until [[ $MEMR =~ ^[+]?[0-9]+$ ]]; do
        echo "[ERROR] Please input a positive integer."
        read -p "[mem]= " MEMR
    done

    read -p "[scratch_local]= " SCRATCH
    until [[ $SCRATCH =~ ^[+]?[0-9]+$ ]]; do
        echo "[ERROR] Please input a positive integer."
        read -p "[scratch_local]= " SCRATCH
    done

    read -p "[walltime (in hours)]= " WALLT
    until [[ $WALLT =~ ^[+]?[0-9]+$ ]]; do
        echo "[ERROR] Please input a positive integer."
        read -p "[walltime]= " WALLT
    done

    echo -e "--------------------\n[INFO] New resource settings:\nncpus=${CPU}\nmem=${MEMR}gb\nscratch_local=${SCRATCH}gb\nwalltime=${WALLT}:00:00\n--------------------"
fi

### Submit the job using qsub with the specified resources
echo "[INFO] Submitting Turbomole calculation."
qsub -l select=1:ncpus=${CPU}:mem=${MEMR}gb:scratch_local=${SCRATCH}gb -l walltime=${WALLT}:00:00 ${DATADIR}/${FILENAME}.sh

# Uncomment the next lines if you wish to remove the submit script after submission
# echo "[INFO] Removing '${FILENAME}.sh'."
# rm ${DATADIR}/${FILENAME}.sh

echo "[EOF] Submission Complete."
