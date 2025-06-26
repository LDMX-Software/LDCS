#!/bin/bash

# a shorthand script to set up config and template aliases at once 
# just makes life on the command line easier

if [ -z $1 ]
then
    echo "Have to pass a config name (with path)! Exiting."
    return 1;
fi

cfgName="$1"

export cfg=${cfgName}
if ! [ -f $cfg ] 
then 
    echo
    echo "Found no config with name $cfgName!"
    echo "Maybe you meant something like this (listing search with wildcards)? :"
    echo 
    echo "------------- "
    ls -lhrt *$cfgName*
    echo "------------- "
    echo 
    echo "Try again."
    return 1;
fi 

tplName="$(grep tpl $cfg | cut -d= -f2 )"
if ! [ -f $(dirname $cfg)/$tplName ]
then
    echo
    echo "Found no template with name $tplName!"
    echo "Maybe you meant something like this (listing search with wildcards)? :"
    echo
    echo "------------- "
    ls -lhrt $(dirname $cfg)/*$tplName*
    echo "------------- "
    echo
    echo "Try again."
    return 1;
fi

export tpl=$(ls $(dirname $cfg)/$(grep tpl $cfg | cut -d= -f2 ))

echo "Using config $cfg"
echo "Using template $tpl"




