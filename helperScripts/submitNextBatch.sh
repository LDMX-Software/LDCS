#!/bin/bash

# Script that automatises batch submission, if run as a cron job. 
# It checks the number of running/waiting/resubmitted or otherwise active jobs in, using the aCT report. 
# Then it increments the batch number and the random seeds set in the config. Finally it submits.

echo "-------------------- STARTING --------------------"
date
echo

if [ -z $1 ]
then 
    echo "A job config name is needed. This config gets updated and then submitted by the script".
    exit
else
    configFile=$1
fi

if [ -z $2 ]
then 
    maxBatches=46    
    echo "Using default maximum final number of batches: $maxBatches"
else
    maxBatches=$2
    echo "Using maximum final number of batches: $maxBatches"
fi

if [ -z $3 ]
then
    minJobs=2500
    echo "Using default threshold on minimum number of active jobs in the system: $minJobs"
else
    minJobs=$3
    echo "Using minimum number of active jobs in the system: $minJobs"
fi

if [ -z $4 ]
then
    waitSeconds=360
    echo "Using default waiting time before setting all sites online/offline as they were before submission: $waitSeconds"
else
    waitSeconds=$4
    echo "Using wating time to set all sites back: $waitSeconds"
    # 6 minutes is ok for longer jobs. 4 (240) better for quick reco. use 2-3 for no input (like sim) or even 0 for dry-runs.
fi





echo 
echo "Considering submission..."
nActiveJobs=$( python /home/centos/src/aCT/src/act/ldmx/countJobs.py )
echo "Query shows $nActiveJobs jobs still active in LDCS"


if [ $nActiveJobs -le $minJobs ]
then #submit more!

    #assume batch naming structure: BatchID=someProductionIdentifier-batch[number] 
    batchName=$(grep BatchID ${configFile} | cut -d"=" -f2 | cut -d"-" -f2)
    let batchNb="${batchName//[!0-9]/}"   #isolate number
    batchID="${batchName//[0-9]/}"        #isolate ID (batch...)
    (( batchNb++ ))

    puDS=$(grep PileupDataset ${configFile} | cut -d"=" -f2)
    if [ "${puDS}" != "" ] ; then 
	let puBatch=$(( batchNb % 3 + 1))
	echo "batch nb is $batchNb and pubatch nb is $puBatch"
	newPuDS=$(echo "${puDS}" | sed "s/batch.*/batch${puBatch}/g" )
	echo "using old pu dataset = $puDS and new = $newPuDS"
    fi
    if [ $batchNb -gt $maxBatches ] 
    then 
	echo "Already submitted enough batches! Limit set to $maxBatches batches total. Turn off the cron job :) "
    else
	echo "Will submit. Last batch was $batchName"    

	#make sure we disable keeping logs
	sed -ie 's,<keepsuccessful>1</keepsuccessful>,<keepsuccessful>0</keepsuccessful>,g' /home/centos/act/etc/act/aCTConfigAPP.xml 
	#WARNING! DIRTY HACK!  -- to be removed 
	#set UCSB temporarily offline to disable local copy jobs going there exclusively 

	siteCfg=/home/centos/act/etc/act/aCTConfigARC.xml
	cp $siteCfg siteCfg.bu
	sed -ie '
/ldmx.cnsi.ucsb.edu/!{x;1!p;d;}
x;s/online/offline/;$G
' $siteCfg

	echo -e "\n </config>" >> $siteCfg

	echo "UCSB config now reads:"
        echo $(grep -A 3 "UCSB" ${siteCfg})

        sed -ie '
/axion.hep.caltech.edu/!{x;1!p;d;}
x;s/online/offline/;$G
' $siteCfg

        echo -e "\n </config>" >> $siteCfg

	echo "Caltech config now reads:"
        echo $(grep -A 3 "CALTECH" ${siteCfg})

	#pull the numbers from the config
	nJobs=$(grep NumberofJobs ${configFile}  | cut -d"=" -f2)
	seedstr=$(grep RandomSeed1SequenceStart ${configFile} | cut -d"=" -f2)
	if [ "${seedstr}" != "" ] ; then  #only there if we're running sim, not pure (re)reco 
	    let seed1=$(grep RandomSeed1SequenceStart ${configFile} | cut -d"=" -f2)
	    let seed2=$(grep RandomSeed2SequenceStart ${configFile} | cut -d"=" -f2)
	    
	    #update them 
	    newSeed1=$(( seed1 + 2*nJobs ))  #used to be incremented by 2*nJobs, but now a different scheme is used
	    newSeed2=$(( seed2 + 2*nJobs ))  #this isn't really used anymore anyway
	    sed -ie 's/RandomSeed1SequenceStart='${seed1}'/RandomSeed1SequenceStart='${newSeed1}'/g' $configFile
	    sed -ie 's/RandomSeed2SequenceStart='${seed2}'/RandomSeed2SequenceStart='${newSeed2}'/g' $configFile
	fi

	#plug in the new values 
	#replace batchX with batchY
	if [ "${puDS}" != "" ] ; then
	    sed -ie 's/'${puDS}'/'${newPuDS}'/g' $configFile
	fi
	sed -ie 's/'${batchName}'/'${batchID}${batchNb}'/g' $configFile

	#print for logging/monitoring
	echo -e "Updated config $configFile now reads:\n\n" 
	cat $configFile

	echo
	date
	echo -e "\nSubmitting $batchID$batchNb. Current job status:"
#	echo "actldmxadmin submit -c $configFile"  #dry run
	actldmxadmin submit -c $configFile
	echo 
	actreport
	echo 
	echo 
	echo "Waiting $waitSeconds seconds, and then setting UCSB/caltech back to previous status"
	sleep ${waitSeconds}                         # comment or use 0 in dry run.
	cp siteCfg.bu ${siteCfg}
	echo "UCSB set back to whatever it was before:"
	echo $(grep -A 3 "UCSB" ${siteCfg})
	echo "Caltech set back to whatever it was before:"
	echo $(grep -A 3 "CALTECH" ${siteCfg})
	
    fi
else
    echo "Already plenty of jobs active in the system. Will try again later, and submit once the number drops below $minJobs"
fi 


echo "--------------------- DONE -----------------------"
echo
