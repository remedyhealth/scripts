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

  aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" --query "Reservations[*].Instances[*].PublicIpAddress" | egrep -o '([0-9]*\.){3}[0-9]*' >> ${OUTDIR}/hosts.txt
}

os_check () {
  HOST=$1
  OUTDIR=$2

  ssh -o PreferredAuthentications=publickey -o ConnectTimeout=2 ashea@${HOST} "exit 0" > /dev/null 2>&1
  if [ "$?" == "0" ]; then
    echo "[YES] SSH ${HOST}"
  else
    echo "[NO] SSH ${HOST}"
  fi

  ssh -tt -o PreferredAuthentications=publickey -o ConnectTimeout=2 -i ~/.ssh/id_rsa_rhm_master thcnadmin@${HOST} "sudo whoami" > /dev/null 2>&1
}

OUTDIR=`mktemp -d`
echo "* Output going to '${OUTDIR}'"
echo "* Gathering IP addresses"
gather_ips $OUTDIR
echo "* Got em! Starting LDAP Auth check..."

for HOST in $(cat ${OUTDIR}/hosts.txt); do
  os_check $HOST $OUTDIR
done

echo "* Complete"
rm -rf ${OUTDIR}
