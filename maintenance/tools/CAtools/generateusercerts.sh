#!/bin/bash -x

#TODO: add better defaults
CADIR=${2:-CA/}
CANAME='LDCS-CA'
CACERT=$CADIR/$CANAME.pem
CAKEY=$CADIR/$CANAME.key
MESSAGEDIGEST='sha512'

USERNAME=${1:-'Simulation Agent'}
# Avoid blank spaces in filenames
USERNAMEDASHES=$(echo $USERNAME | tr ' ' '-')
SUBJECTHEAD='/DC=org/DC=nordugrid/DC=ARC/O=LDMX/CN='
SUBJECT="$SUBJECTHEAD$USERNAME"

# Generate hostkey

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




