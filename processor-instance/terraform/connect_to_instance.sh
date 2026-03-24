#!/bin/bash

# Get the instance IP
SCWDOCKER=`terraform output | grep address | head -1 | awk '{print $3}' | sed "s/\"//g"`

# remove from known_hosts as new instances can have the same IP
grep -v $SCWDOCKER ~/.ssh/known_hosts > /tmp/hosts
mv /tmp/hosts ~/.ssh/known_hosts

# note: assumes installed SSH key
ssh root@${SCWDOCKER}

