#!/bin/bash

# Script that automatises batch submission, if run as a cron job. 
# It checks the number of running/waiting/resubmitted or otherwise active jobs in, using the aCT report. 
# Then it increments the batch number and the random seeds set in the config. Finally it submits.

echo "-------------------- STARTING --------------------"
date
echo

if [ -z $1 ]
then 
    echo "A campaign list is needed"
    exit
else
    campaignList=$1
fi

echo 

#we will assume that the user can add a campaign id to the bottom of a file 

#campaignID=$(grep BatchID ${configFile} | cut -d"=" -f2 | cut -d"-" -f1)
while read -r line; do 
    campaignID="${line}"
    echo "checking campaign ${campaignID}"
    nActiveJobs=$( python /home/centos/src/aCT/src/act/ldmx/countJobsPerCampaign.py -b "${campaignID}")
    echo $nActiveJobs > /home/centos/act/currentJobCount_${campaignID}
    echo "it had $nActiveJobs jobs"
done < $campaignList
nActiveJobsTotal=$( python /home/centos/src/aCT/src/act/ldmx/countJobs.py )
echo "Query shows $nActiveJobsTotal jobs still active in LDCS"
echo $nActiveJobsTotal > /home/centos/act/currentJobCount
