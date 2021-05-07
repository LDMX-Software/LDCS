###############################################################################
# Script to Build Singularity Production Image from Docker
# Assumptions:
#   1. Have singularity installed and can run `singularity build`
#   2. User is running this script from where they want the singularity image to be
#
# Example Usage:
#   Download latest docker production container:
#       bash build_from_docker.sh
#   Specify a docker production container tag:
#       bash build_from_docker.sh v2.0.0
#   Specify a docker container tag from the dev repo:
#       bash build_from_docker.sh latest "ldmx/dev"
#
# Author: Tom Eichlersmith, eichl008@umn.edu
# Written: July, 2020
# Edits and tweaks: Lene Kristian Bryngemark, Stanford University, lkbryng@stanford.edu
###############################################################################

_docker_tag="latest"
if [ -z "$1" ]
then
    echo "No tag provided, will use '${_docker_tag}' tag."
else
    _docker_tag="$1"
fi

_docker_repo="ldmx/pro"
if [ -z "$2" ]
then
    echo "No repo provided, will use '${_docker_repo}' repo."
else
    _docker_repo="$2"
fi

# the dependency versions are set in the docker container ldmx/dev
# parsing these versions out of that container is very difficult, so
#   right now I am hard-coding them into the file name.
# You can find the docker build context for the development container
#   in the GitHub repo LDMX-Software/docker and get all the details
#   of the container using `docker inspect`

export SINGULARITY_CACHEDIR=${PWD}/.singularity
mkdir -p ${SINGULARITY_CACHEDIR} #make sure cache directory exists

G4tag="10.2.3_v0.4"
ROOTtag="6.22.00"
ONNXtag="1.3.0"
XERCEStag="3.2.3"
UBUNTUtag="18.04"
#remove the "owner" of the repo (like, ldmx) from the repo name used in image naming -- so it typically becomes 'pro'
repoName="${_docker_repo##*/}"
tagName="${repoName}_${_docker_tag}"
image="ldmx-${tagName}-gLDMX.${G4tag}-r${ROOTtag}-onnx${ONNXtag}-xerces${XERCEStag}-ubuntu${UBUNTUtag}.sif"
location="docker://${_docker_repo}:${_docker_tag}"
echo "pulling from $location to build image $image"

singularity build ${image} ${location}

#singularity build \
#    ldmx-${_docker_tag}-gLDMX.10.2.3_v0.3-r6.20.00-onnx1.3.0-xerces3.2.3-ubuntu18.04.sif \
#    docker://ldmx/pro:${_docker_tag}

RETURN=$?
if [ $RETURN -ne 0 ]
   echo "Image building returned exit code $RETURN!"
   exit $RETURN
fi
   
export FULLIMAGEPATH="${PWD}/${image}"
