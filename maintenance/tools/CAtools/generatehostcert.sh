#!/bin/bash -x

#TODO: add defaults
CADIR=${2:-CA/}
CANAME='LDCS-CA'
CACERT=$CADIR/$CANAME.pem
CAKEY=$CADIR/$CANAME.key
MESSAGEDIGEST='sha512'

HOSTNAME=$1
SUBJECTHEAD='/DC=org/DC=nordugrid/DC=ARC/O=LDMX/CN=host\/'
SUBJECT="$SUBJECTHEAD$HOSTNAME"

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




