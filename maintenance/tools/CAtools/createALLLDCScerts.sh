#/bin/bash -x

echo "This script generates all required LDCS certificates as per 2026-03-20"

if [ ! -e generatehostcert.sh ] || [ ! -e generateusercert.sh ]; then
   echo "generatehostcert.sh and generateusercert.sh not found. Cannot continue. Exiting..."
   exit 1
fi

echo "generating hostcerts"
echo "create file hostlist.txt and add one FQDN per line"
for host in `cat hostlist.txt | xargs`; do
   ./generatehostcert.sh $host
done

echo "generating user certs"
   ./generateusercert.sh 'Simulation Agent'
   ./generateusercert.sh 'Analysis Agent'




