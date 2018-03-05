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
}

ssh ${SSH_USERNAME}@${HOST} "grep ${APT_MIRROR} /etc/apt/sources.list.d/ubuntu-trusty.list" > /dev/null 2>&1

OUTDIR=`mktemp -d`
echo "* Output going to '${OUTDIR}'"
echo "* Gathering IP addresses from ${VPCS}"
gather_ips $OUTDIR
echo "* Got em! Starting sshs..."

for HOST in $(cat ${OUTDIR}/hosts.txt); do
  ssh $HOST
done

echo "* Complete"

echo "Removing outdir for testing"
rm -rf $OUTDIR
