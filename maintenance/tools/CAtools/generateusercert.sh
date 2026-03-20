#!/bin/bash -x

#TODO: add better defaults
DEFAULTCAPATH=$(realpath CA)
CADIR=${2:-"$DEFAULTCAPATH/"}
CANAME='LDCS-CA'
CACERT=$CADIR/$CANAME.pem
CAKEY=$CADIR/$CANAME.key
MESSAGEDIGEST='sha512'

USERNAME=${1:-'Simulation Agent'}
# Avoid blank spaces in filenames
USERNAMEDASHES=$(echo $USERNAME | tr ' ' '-')
SUBJECTHEAD='/DC=org/DC=nordugrid/DC=ARC/O=LDMX/CN='
SUBJECT="$SUBJECTHEAD$USERNAME"

TARGET="usercerts/$USERNAMEDASHES"

echo "This script will create a LDCS user certificate in the directory $TARGET"
echo "if the directory does not exist it will be created"


if [[ $# -lt 1 ]] || [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
   echo "    Usage: $0 'user name' [CADIR]"
   echo "    'user name' : Quoted user name e.g. 'Simulation Agent'"
   echo "    CADIR : directory containing LDCS CA. Default is CA in current folder"
   exit 1
fi

if [ ! -d $TARGET ]; then
   echo "Creating directory $TARGET"
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

# Generate userkey

openssl genrsa -out userkey-$USERNAMEDASHES.key 4096

# Generate csr
openssl req -new -$MESSAGEDIGEST -subj "$SUBJECT" -key userkey-$USERNAMEDASHES.key -out usercert-$USERNAMEDASHES.csr

#generate config

cat << EOF > x509v3_config-$USERNAMEDASHES
basicConstraints=CA:FALSE
keyUsage=digitalSignature, nonRepudiation, keyEncipherment
EOF

# Sign certificate with CA

openssl x509 -req -$MESSAGEDIGEST -in usercert-$USERNAMEDASHES.csr -CA $CACERT -CAkey $CAKEY -CAcreateserial -extfile x509v3_config-$USERNAMEDASHES -out usercert-$USERNAMEDASHES.pem -days 365


# Create softlinks
ln -s userkey-$USERNAMEDASHES.key userkey.pem 
ln -s usercert-$USERNAMEDASHES.pem usercert.pem
cp ../../setenv.sh .
