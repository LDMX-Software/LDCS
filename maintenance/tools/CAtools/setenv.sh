# This script can be used to initialize the user environment for testing.
basedir=$(dirname `readlink -f -- ${BASH_SOURCE:-$_}`)
export X509_USER_CERT="$basedir/usercert.pem"
export X509_USER_KEY="$basedir/userkey.pem"
export X509_USER_PROXY="$basedir/userproxy.pem"
export X509_CERT_DIR="$basedir/../CA"
