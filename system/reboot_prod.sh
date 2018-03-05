#!/bin/bash
#set -x
#
# Reboots all production systems 
#
# 1. Copy baseline_check.cfg to ~/.baseline_check.cfg and update values
# 2. ./reboot_prod.sh
#

if [ ! -f ~/.baseline_check.cfg ]; then
  echo "~/.baseline_check.cfg does not exist!"
  exit 1
fi

. ~/.baseline_check.cfg

gather_ids () {
  OUTDIR=$1

  echo "* Gathering Production instance IDs from ${VPCS}"
  cd ${CHEF_REPO} && knife node list -E production > ${OUTDIR}/chef_hosts.txt
  for host in $(cat ${OUTDIR}/chef_hosts.txt); do
    IP=$(host ${host}.rmdy.hm | egrep -o '([0-9]*\.){3}[0-9]*')
    INSTANCE_ID=$(aws ec2 describe-instances --filters "Name=ip-address,Values=${IP}" --query "Reservations[*].Instances[*].InstanceId" | egrep -o 'i-\w+')
    if [ ! -z "${INSTANCE_ID}" ]; then
      echo $INSTANCE_ID,$IP >> ${OUTDIR}/hosts.txt
    fi
  done;
  aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" "Name=vpc-id,Values=[${VPCS}]" "Name=tag:opsworks:stack,Values=*Prod*" --query "Reservations[*].Instances[*].InstanceId" | egrep -o 'i-\w+' >> ${OUTDIR}/opsworks_hosts.txt
  for INSTANCE_ID in $(cat ${OUTDIR}/opsworks_hosts.txt); do
    IP=$(aws ec2 describe-instances --filters "Name=instance-id,Values=${INSTANCE_ID}" --query "Reservations[*].Instances[*].PublicIpAddress" | egrep -o '([0-9]*\.){3}[0-9]*')
    echo $INSTANCE_ID,$IP >> ${OUTDIR}/hosts.txt
  done
  echo "* Gathering ELB names"
  for i in $(aws elb describe-load-balancers --query LoadBalancerDescriptions[*].[Instances,LoadBalancerName] | egrep -v '(\[|\]|\{|\})' | awk -F\" '{print $(NF-1)}'); do
    echo $i | grep '^i-' > /dev/null
    if [ "$?" == "0" ]; then
      echo -n $i, >> ${OUTDIR}/elbs.txt
    else
      echo $i >> ${OUTDIR}/elbs.txt
    fi
  done
  rm ${OUTDIR}/chef_hosts.txt
  rm ${OUTDIR}/opsworks_hosts.txt
}

reboot_server () {
  INSTANCE_ID=$1
  IP=$2
  OUTDIR=$3
  HOST_NAME=$(ssh ${SSH_USERNAME}@${IP} "hostname -f" 2>/dev/null)
  HOST_NAME_SHORT=$(ssh ${SSH_USERNAME}@${IP} "hostname" 2>/dev/null)

  echo "${HOST_NAME_SHORT}:"
  echo "  ip: ${IP}"
  echo "  instance-id: ${INSTANCE_ID}"
  aws ec2 reboot-instances --instance-ids ${INSTANCE_ID}
  sleep 30
  STATUS=`aws ec2 describe-instance-status --instance-ids ${INSTANCE_ID} | grep passed | wc -l | grep 2`
  while [ $? -ne 0 ]; do
    sleep 10
    STATUS=`aws ec2 describe-instance-status --instance-ids ${INSTANCE_ID} | grep passed | wc -l | grep 2`
  done;
  echo "  EC2 status-checks: 2/2"
  grep ${INSTANCE_ID} ${OUTDIR}/elbs.txt > /dev/null
  if [ $? -eq 0 ]; then
    sleep 30
    ELB_NAME=`grep ${INSTANCE_ID} ${OUTDIR}/elbs.txt | awk -F, '{print $NF}'`
    echo -n "  ELB ${ELB_NAME} status-checks: "
    sleep 30
    ELB_STATUS=`aws elb describe-instance-health --load-balancer-name ${ELB_NAME} | grep -A3 ${INSTANCE_ID} | grep State | awk -F\" '{print $4}' | grep InService`
    while [ $? -ne 0 ]; do
      sleep 10
      ELB_STATUS=`aws elb describe-instance-health --load-balancer-name ${ELB_NAME} | grep -A3 ${INSTANCE_ID} | grep State | awk -F\" '{print $4}' | grep InService`
    done 
    echo "OK"
  fi
}

OUTDIR=`mktemp -d`
#OUTDIR="/var/folders/hw/4nv54xc11mv854z2sfw7sc2r0000gn/T/tmp.BkqcxbWu"
echo "* Output going to '${OUTDIR}'"
gather_ids $OUTDIR
echo "* Got em! Starting reboot process..."

for HOST in $(cat ${OUTDIR}/hosts.txt); do
  INSTANCE_ID=$(echo $HOST | awk -F, '{print $1}')
  IP=$(echo $HOST | awk -F, '{print $2}')
  echo "Rebooting $INSTANCE_ID ..."
  reboot_server $INSTANCE_ID $IP $OUTDIR
done

echo "* Complete"

rm -rf $OUTDIR
