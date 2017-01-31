#!/bin/bash
#set -x
#
# Validates that all systems on the given VPCs match a baseline criteria
#
# 1. Copy baseline_check.cfg to ~/.baseline_check.cfg and update values
# 2. ./baseline_check.sh
#
# Output will go to a tmpdir that is displayed in the output
#

if [ ! -f ~/.baseline_check.cfg ]; then
  echo "~/.baseline_check.cfg does not exist!"
  exit 1
fi

. ~/.baseline_check.cfg

gather_ips () {
  OUTDIR=$1

  aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" "Name=vpc-id,Values=[${VPCS}]" --query "Reservations[*].Instances[*].PrivateIpAddress" | egrep -o '([0-9]*\.){3}[0-9]*' > ${OUTDIR}/hosts.txt
  aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" "Name=vpc-id,Values=[${VPCS_OLD}]" --query "Reservations[*].Instances[*].PublicIpAddress" | egrep -o '([0-9]*\.){3}[0-9]*' >> ${OUTDIR}/hosts.txt
}

os_check () {
  HOST=$1
  OUTDIR=$2

  echo "* Gathering OS from ${HOST}"
  OS=`ssh -o PreferredAuthentications=publickey -o ConnectTimeout=2 ${SSH_USERNAME}@${HOST} "lsb_release -s -d || head -n1 /etc/issue" 2> /dev/null`
  if [ "$?" == "0" ]; then
    HOST_NAME=$(ssh ${SSH_USERNAME}@${HOST} "hostname -f")
    echo "$HOST,$HOST_NAME,$SSH_USERNAME,id_rsa,$OS" >> "${OUTDIR}/os.txt"
    return
  fi
  echo "* Could not login to $HOST as ${SSH_USERNAME}... Trying ashea"

  OS=`ssh -o PreferredAuthentications=publickey -o ConnectTimeout=2 ashea@${HOST} "lsb_release -s -d || head -n1 /etc/issue" 2> /dev/null`
  if [ "$?" == "0" ]; then
    HOST_NAME=$(ssh ashea@${HOST} "hostname -f")
    echo "$HOST,$HOST_NAME,ashea,id_rsa,$OS" >> "${OUTDIR}/os.txt"
    return
  fi
  echo "* Could not login to $HOST as ashea... Trying default accounts"

  for username in "ubuntu" "ec2-user" "root"; do
    OS=`ssh -o PreferredAuthentications=publickey -o ConnectTimeout=2 -i ${RHM_MASTER_KEY} ${username}@${HOST} "lsb_release -s -d || head -n1 /etc/issue" 2> /dev/null`
    if [ "$?" == "0" ]; then
      HOST_NAME=$(ssh -o PreferredAuthentications=publickey -o ConnectTimeout=2 -i ${RHM_MASTER_KEY} ${username}@${HOST} "hostname -f || echo ${HOST}")
      echo "$HOST,$HOST_NAME,$username,${RHM_MASTER_KEY},$OS" >> "${OUTDIR}/os.txt"
      return
    fi
  done

  for username in "ubuntu" "ec2-user" "root"; do
    OS=`ssh -o PreferredAuthentications=publickey -o ConnectTimeout=2 -i ${TURNKEY_KEY} ${username}@${HOST} "lsb_release -s -d || head -n1 /etc/issue" 2> /dev/null`
    if [ "$?" == "0" ]; then
      HOST_NAME=$(ssh -o PreferredAuthentications=publickey -o ConnectTimeout=2 -i ${TURNKEY_KEY} ${username}@${HOST} "hostname -f || echo ${HOST}")
      echo "$HOST,$HOST_NAME,$username,${TURNKEY_KEY},$OS" >> "${OUTDIR}/os.txt"
      return
    fi
  done

  echo "* Could not login to $HOST"
  echo "$HOST,,Could not login" >> "${OUTDIR}/os.txt"
}

OUTDIR=`mktemp -d`
echo "* Output going to '${OUTDIR}'"
echo "* Gathering IP addresses"
gather_ips $OUTDIR
echo "* Got em! Starting OS check..."

echo "ip,hostname,username,ssh_key,os" > "${OUTDIR}/os.txt"
for HOST in $(cat ${OUTDIR}/hosts.txt); do
  os_check $HOST $OUTDIR
done

echo "* Complete"

#echo "Removing outdir for testing"
#rm -rf $OUTDIR
