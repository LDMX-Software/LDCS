#!/bin/bash
#
# Wrapper script for LDMX simulation
#

echo -e "ldmxsim.sh running on host $(/bin/hostname -f)\n"

# Check all files are present
for f in "ldmxproduction.config" "ldmxjob.py" "ldmx-simprod-rte-helper.py"; do
  if [ ! -f "$f" ]; then
    echo "ERROR: LDMX Simulation production job requires $f file but it is missing" >&2
    exit 1
  fi
done

echo -e "ldmxproduction.config:\n"
cat ldmxproduction.config
echo
echo


echo -e "ldmxjob.py:\n--------------------------\n "
cat ldmxjob.py
echo -e "--------------------------\n "echo
echo


# Check env vars are defined properly by RTE
if [ -z "$LDMX_STORAGE_BASE" ]; then
  echo "ERROR: ARC CE admin should define LDMX_STORAGE_BASE with arcctl rte params-set"
  exit 1
fi

# Check singularity is installed
type singularity
if [ $? -ne 0 ]; then
  echo "ERROR: Singularity installation on the worker nodes is required to run LDMX software"
  exit 1
fi

# Initialise some parameters
eval $( python3 ldmx-simprod-rte-helper.py -c ldmxproduction.config init )
echo -e "Output data file is $OUTPUTDATAFILE\n"
echo "After init, using singularity image env var $SINGULARITY_IMAGE"
echo "Check: is it in local dir?"
ls 

#check after init, which is allowed to let the SINGULARITY_IMAGE point to a custom image 
if [ -z "$SINGULARITY_IMAGE" ]; then
  echo "ERROR: pass an input singularity image, or, ARC CE admin should define SINGULARITY_IMAGE with arcctl rte params-set"
  exit 1
fi


# Copy over local replica to the worker node (singularity can't see unmounted dirs like storage)
python3 ldmx-simprod-rte-helper.py -c ldmxproduction.config copy-local

#untar any madgraph lhe file library tarballs 
find . -name LDMX_*.tar.gz -exec tar -xvzf {} \;
#tar -xvzf LDMX_*.tar.gz

if [ ! -f $SINGULARITY_IMAGE ]
then
	echo -e "Couldn't find singularity image $SINGULARITY_IMAGE as file after all!"
	ls
	exit 1
fi

# Start the simulation container
echo -e "Starting Singularity image $SINGULARITY_IMAGE\n"
#singularity run $SINGULARITY_OPTIONS --home "$PWD" "${SINGULARITY_IMAGE}" . ldmxjob.py
singularity exec $SINGULARITY_OPTIONS --home "$PWD" "${SINGULARITY_IMAGE}" . ldmxjob.py
RET=$?

if [ $RET -ne 0 ]; then
  echo "Singularity exited with code $RET"
  exit $RET
fi

echo -e "\nSingularity exited normally, proceeding with post-processing...\n"

# Post processing to extract metadata for rucio
eval $( python3 ldmx-simprod-rte-helper.py -j rucio.metadata -c ldmxproduction.config  collect-metadata )
if [ ! -z "$KEEP_LOCAL_COPY" ]; then
  if [ -z "$FINALOUTPUTFILE" ]; then
    echo "Post-processing script failed!"
    exit 1
  fi

  echo "Copying $OUTPUTDATAFILE to $FINALOUTPUTFILE"
  mkdir -p "${FINALOUTPUTFILE%/*}"
  cp "$OUTPUTDATAFILE" "$FINALOUTPUTFILE"
  if [ $? -ne 0 ]; then
    echo "Failed to copy output to final destination"
    exit 1
  fi
else
  echo "KEEP_LOCAL_COPY is not set, not storing local copy of output"
fi


# Success
echo "Success, exiting..."
exit 0

