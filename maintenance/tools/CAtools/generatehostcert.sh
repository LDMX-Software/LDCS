#!/bin/bash -x

#TODO: add defaults?
# TODO: add usage function
DEFAULTCAPATH=$(realpath CA)
CADIR=${2:-"$DEFAULTCAPATH/"}
CANAME='LDCS-CA'
CACERT=$CADIR/$CANAME.pem
CAKEY=$CADIR/$CANAME.key
MESSAGEDIGEST='sha512'

HOSTNAME=$1
SUBJECTHEAD='/DC=org/DC=nordugrid/DC=ARC/O=LDMX/CN=host\/'
SUBJECT="$SUBJECTHEAD$HOSTNAME"

TARGET="hostcerts/$HOSTNAME"

echo "This script will create a host certificate in the directory $TARGET"
echo "if the directory does not exist it will be created"


if [[ $# -lt 1 ]] || [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
   echo "    Usage: $0 FQDN [CADIR]"
   echo "    FQDN : Fully Qualified Hostname e.g. l-pilot2.lunarc.lu.se"
   echo "    CADIR : directory containing LDCS CA. Default is CA in current folder"
   exit 1
fi

if [ ! -d $TARGET ]; then
   echo "Creating directory hostcerts"
   mkdir -p $TARGET
   if [[ $? != 0 ]]; then
      echo "failed to create $TARGET dir, cannot continue"
      exit 1
   fi
fi

cd $TARGET

if [ ! -d "$CADIR" ] || [ ! -e "$CADIR/LDCS-CA.pem" ]; then
  echo "missing or invalid CA directory $CADIR . Cannot continue"
  exit 1
fi

# Generate hostkey

openssl genrsa -out $HOSTNAME.key 4096

# Generate csr
openssl req -new -$MESSAGEDIGEST -subj "$SUBJECT" -key $HOSTNAME.key -out $HOSTNAME.csr

#generate config

cat << EOF > x509v3_config-$HOSTNAME
basicConstraints=CA:FALSE
keyUsage=digitalSignature, nonRepudiation, keyEncipherment
subjectAltName=DNS:$HOSTNAME
EOF

# Sign certificate with CA

openssl x509 -req -$MESSAGEDIGEST -in $HOSTNAME.csr -CA $CACERT -CAkey $CAKEY -CAcreateserial -extfile x509v3_config-$HOSTNAME -out $HOSTNAME.pem -days 365




