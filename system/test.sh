#!/bin/bash

for i in $(aws elb describe-load-balancers --query LoadBalancerDescriptions[*].[Instances,LoadBalancerName] | egrep -v '(\[|\]|\{|\})' | awk -F\" '{print $(NF-1)}'); do
  echo $i | grep '^i-' > /dev/null
  if [ "$?" == "0" ]; then
    echo -n $i, 
  else
    echo $i
  fi
done