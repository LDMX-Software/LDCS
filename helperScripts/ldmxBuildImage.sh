#!/bin/bash
#
# Wrapper script for LDMX simulation
#

echo -e "ldmxBuildImage.sh running on host $(/bin/hostname -f)\n"

# Check all files are present
# TODO
#  possibly rename the production config
#  bypass submit requirement that a job template exists in bufferdir

for f in "ldmxproduction.config" "ldmx-simprod-rte-helper.py"; do
  if [ ! -f "$f" ]; then
    echo "ERROR: LDMX Simulation production job requires $f file but it is missing" >&2
    exit 1
  fi
done

echo -e "ldmxproduction.config:\n"
cat ldmxproduction.config
echo
echo


#this should not be needed 
#if [ -z "$SINGULARITY_IMAGE" ]; then
#  echo "ERROR: ARC CE admin should define SINGULARITY_IMAGE with arcctl rte params-set"
#  exit 1
#fi

# Check singularity is installed
type singularity
if [ $? -ne 0 ]; then
  echo "ERROR: Singularity installation on the worker nodes is required to run LDMX software"
  exit 1
fi

# Initialise some parameters
# potentially have a separate init function for image building 
eval $( python3 ldmx-simprod-rte-helper.py -c ldmxproduction.config --makeImage init )
if [ -z "$OUTPUTDATAFILE" ]; then
	echo "ERROR: Job config must define output image name"
	exit 1
fi
echo -e "Output data file is $OUTPUTDATAFILE\n"
if [ -z "${DOCKER_REPO}" ]; then
    echo "ERROR: Job config must define input docker container repository"
	exit 1
echo -e "Using DockerHub repository ${DOCKER_REPO}"
if [ -z "${DOCKER_TAG}" ]; then
    echo "ERROR: Job config must define input docker container tag"
	exit 1
echo -e	"Using DockerHub container tag ${DOCKER_TAG}"

# Copy over local replica to the worker node (singularity can't see unmounted dirs like storage)
# not needed for the image generation step but for using it later 
# python3 ldmx-simprod-rte-helper.py -c ldmxproduction.config copy-local


# The dependency versions are set in the docker container ldmx/dev
# Parsing these versions out of that container is very difficult, so
#   right now you need to provide them in the config, for porting to rucio.
# You can find the docker build context for the development container
#   in the GitHub repo LDMX-Software/docker and get all the details
#   of the container using `docker inspect`

export SINGULARITY_CACHEDIR=${PWD}/.singularity
mkdir -p ${SINGULARITY_CACHEDIR} #make sure cache directory exists

#build the image from the repo 
image="${$OUTPUTDATAFILE}.sif"
image=$(sed -e 's/.sif.sif/.sif/g' <<< $image)
location="docker://${DOCKER_REPO}:${DOCKER_TAG}"
echo "pulling from DockerHub $location to build singularity image $image"

singularity build ${image} ${location}
RET=$?

if [ $RET -ne 0 ]; then
  echo "Singularity exited with code $RET"
  exit $RET
fi

echo -e "\nSingularity exited normally, proceeding with post-processing...\n"

# Post processing to extract metadata for rucio
#eval $( python3 ldmx-simprod-rte-helper.py -j rucio.metadata -c ldmxproduction.config  collect-metadata )
eval $( python3 ldmx-simprod-rte-helper.py -c ldmxproduction.config  collect-metadata-image )
if [ ! -z "$KEEP_LOCAL_COPY" ]; then
  if [ -z "$FINALOUTPUTFILE" ]; then
    echo "Post-processing script failed!"
    exit 1
  fi
  #the below should really only differ by a path 
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

