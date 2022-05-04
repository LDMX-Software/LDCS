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

if [ ! -f ${configFile} ] 
then
    echo "${configFile} doesn't exist! Check the path and file name. Exiting."
    exit 
fi 

if [ -z $2 ]
then 
    maxBatches=2    
    echo "Using default maximum final number of batches: $maxBatches. Change this by providing the desired number as arg 2"
else
    maxBatches=$2
    echo "Using maximum final number of batches: $maxBatches"
fi

if [ -z $3 ]
then
    minJobs=2500
    echo "Using default threshold on minimum number of active jobs in the system: $minJobs. Change this by providing the desired number as arg 3"
else
    minJobs=$3
    echo "Using minimum number of active jobs in the system: $minJobs"
fi



echo 
echo "Considering submission..."
campID=$(grep BatchID ${configFile})
echo "full batch name is ${campID}"
campID=$(echo ${campID} | cut -d"=" -f2 | cut -d"-" -f1)
if grep -wq "${campID}" /home/centos/act/currentCampaigns.lst ; then 
    echo "campaign ${campID} already added to list of campaigns to count jobs for"
else 
    #this is a new campaign, add it to the list for periodic job to check 
    echo "${campID}" >> /home/centos/act/currentCampaigns.lst 
    sleep 62 #wait for cron job to look this up 
fi
nNewJobs=$(grep NumberofJobs ${configFile}  | cut -d"=" -f2)
nActiveJobs=$(cat /home/centos/act/currentJobCount_${campID} )
nActiveJobsTotal=$(cat /home/centos/act/currentJobCount )
echo "Query shows $nActiveJobs jobs still active in LDCS matching campaign ID: $campID"

maxTotalJobs=50000 #maximum for entire system 

if [ $nActiveJobs -le $minJobs ]
then #submit more!
    newTot=$((nActiveJobsTotal + nNewJobs))
    if [ "$newTot" -gt "$maxTotalJobs" ]
    then 
	echo "Submitting $nNewJobs job(s) now would lead to $newTot jobs, exceeding the cap on total number of jobs in the system ($maxTotalJobs). Won't submit."
    else 

	#assume batch naming structure: BatchID=someProductionIdentifier-batch[number] 
	batchName=$(grep BatchID ${configFile} | cut -d"=" -f2 | cut -d"-" -f2)
	let batchNb="${batchName//[!0-9]/}"   #isolate number
#	batchID=$("${batchName//[0-9]/}" | tr -d '[:space:]')        #isolate ID ("batch"...)
	batchID="${batchName//[0-9]/}"
	batchID=$(echo $batchID | tr -d '[:space:]')        #isolate ID ("batch"...)
	(( batchNb++ ))

	puDS=$(grep PileupDataset ${configFile} | cut -d"=" -f2)
	if [ "${puDS}" != "" ] ; then  
	    let puBatch=$(( batchNb % 3 + 1))  #we have 3 pileup datasets to rotate
	    echo "batch nb is $batchNb and pubatch nb is $puBatch"
	    newPuDS=$(echo "${puDS}" | sed "s/batch.*/batch${puBatch}/g" )
	    echo "using old pu dataset = $puDS and new = $newPuDS"
	fi
	if [ $batchNb -gt $maxBatches ] 
	then 
	    echo "Already submitted enough batches! Limit set to $maxBatches batches total. Turn off the cron job :) "
	else
	    echo "Will submit. Last batch was $batchName"    

	    #pull the numbers from the config
	    nJobs=$(grep NumberofJobs ${configFile}  | cut -d"=" -f2)
	    seedstr=$(grep RandomSeed1SequenceStart ${configFile} | cut -d"=" -f2)
	    if [ "${seedstr}" != "" ] ; then  #only there if we're running sim, not pure (re)reco 
		let seed1=$(grep RandomSeed1SequenceStart ${configFile} | cut -d"=" -f2)
		let seed2=$(grep RandomSeed2SequenceStart ${configFile} | cut -d"=" -f2)
		echo "original seed 1: $seed1"
		echo "original seed 2: $seed2"
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
	    echo "batch name was: ${batchName} and is getting updated to ${batchID}${batchNb} in $configFile"
	    sed -ie "s/${batchName}/${batchID}${batchNb}/g" $configFile

	    #print for logging/monitoring
	    echo -e "Updated config $configFile now reads:\n\n" 
	    cat $configFile

	    echo
	    date
	    echo -e "\nSubmitting $batchID$batchNb. Current job status:"
	    echo "command is actldmxadmin submit -c $configFile"  #dry run
	    actldmxadmin submit -c $configFile
	    echo 
	    #actreport
	    echo 
	    
	fi
    fi
else
    echo "Already plenty of jobs active in the system. Will try again later, and submit once the number drops below $minJobs"
fi 


echo "--------------------- DONE -----------------------"
echo
