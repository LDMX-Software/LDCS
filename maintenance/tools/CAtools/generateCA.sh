#!/bin/bash -x

SUBJECT='/DC=org/DC=nordugrid/DC=ARC/O=LDMX/CN=LDCS CA'
CANAME='LDCS-CA'
MESSAGEDIGEST='sha512'
VALIDITYPERIOD='1460'


# Generate key
openssl genrsa -out $CANAME.key 4096 

# Generate self-signed CSR and cert
openssl req -x509 -new -${MESSAGEDIGEST} -subj "$SUBJECT" -key $CANAME.key -days $VALIDITYPERIOD -out $CANAME.pem

# Generate signing policy
cat << EOF > $CANAME.signing_policy
access_id_CA  X509   '/DC=org/DC=nordugrid/DC=ARC/O=LDMX/CN=LDCS CA'
pos_rights    globus CA:sign
cond_subjects globus '"/DC=org/DC=nordugrid/DC=ARC/O=LDMX/*"'
EOF

# Generate hash links
CERTHASH=$(openssl x509 -subject_hash -subject_hash_old -noout -in $CANAME.pem)

for h in $CERTHASH; do 
   ln -s $CANAME.pem $h.0
   ln -s $CANAME.signing_policy $h.signing_policy
done



