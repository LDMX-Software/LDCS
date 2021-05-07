#!/bin/bash

if [ -z "$1" ] ;   then 
	echo -e "Error: must specify name (the xyz of LDMX-xyz) for the RTE as first argument; exiting "
	exit 1
fi
RTEname="LDMX-$1"
RTEname=$(sed -e 's,LDMX-LDMX,LDMX,g' <<< $RTEname)
echo "Using RTE name $RTEname"

if [ -z "$2" ] ; then
	swTag="v$1"
	echo "Using default image naming scheme: vX.Y.Z"
else
	swTag="$2"
fi
echo "Using tag name $swTag"


if [ -z "$3" ] ; then
    swRepo=""
    echo "No repo name provided; will rely on build script default"
else
    swRepo="$3"
	echo "Using sw repo name $swTag"
fi


	
startDir=${PWD}
source sitePathSetup.config

cd $LDCSPATH
git fetch && git pull origin master


cd $IMAGEPATH
bash $LDCSPATH/images/build_from_docker.sh ${swTag} ${swRepo}
imageBuildReturn=$?

cd ${startDir}

if [ ${imageBuildReturn} -ne 0 ] ; then
	echo "Image building unsuccessful."
	if [ "${FULLIMAGEPATH}" !=  '.' ] && [ -f ${FULLIMAGEPATH} ] ; then
		echo "Continuing setup with previously successfully built image ${FULLIMAGEPATH}."
	else
		echo -e "Error: singularity image ${FULLIMAGEPATH} not found! RTE not enabled."
		exit $imageBuildReturn
	fi
else 
echo "Using successfully built image at path ${FULLIMAGEPATH}"
fi

cp ${LDCSPATH}/runTimeEnvironments/${RTEname} ${RTEPATH}/APPS/.
arcctl rte params-set ${RTEPATH}/APPS/${RTEname} SINGULARITY_IMAGE ${FULLIMAGEPATH}
arcctl rte enable ${RTEPATH}/APPS/${RTEname}

