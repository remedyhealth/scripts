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

eval_result () {
  RESULT=$1
  EXPECTED=$2
  DESC=$3

  if [ "${RESULT}" == "${EXPECTED}" ]; then
    MARKER="PASS"
  else
    MARKER="FAIL"
  fi

  echo "[${MARKER}] $DESC"
}

auth_checks () {
  HOST=$1

  echo "* Authorization and Authentication Checks"
  ssh -i ${RHM_MASTER_KEY} ubuntu@${HOST} 'whoami' > /dev/null 2>&1
  eval_result "$?" "255" "RHM master key cannot login in"

  ssh ${SSH_USERNAME}@${HOST} 'whoami' > /dev/null 2>&1
  eval_result "$?" "0" "${SSH_USERNAME} can login in"

  ssh ${SSH_USERNAME}@${HOST} 'echo "" | sudo -S whoami' > /dev/null 2>&1
  eval_result "$?" "1" "${SSH_USERNAME} cannot sudo without a password"
}

port_checks () {
  HOST=$1
  HOST_NAME=$(ssh ${SSH_USERNAME}@${HOST} "hostname -f")

  echo "* Open Ports Checks"
  for port in `nmap $HOST -PN | grep open | awk -F/ '{print $1}'`; do
    case $port in
      22|80|443|1443)
        eval_result "0", "0", "${port} is open"
        ;;
      25)
        if [ "$HOST_NAME" != "${POSTFIX_MAILRELAY}" ]; then
          eval_result "1", "0", "${port} is closed"
        fi
        ;;
      514|20514)
        if [ "$HOST_NAME" != "${LOGSERVER}" ]; then
          eval_result "1", "0", "${port} is closed"
        fi
        ;;
      *)
        eval_result "1", "0", "${port} is closed"
    esac
  done
}

service_checks () {
  HOST=$1
  HOST_NAME=$(ssh ${SSH_USERNAME}@${HOST} "hostname -f")

  echo "* Services Configuration Checks"
  if [ "$HOST_NAME" != "${POSTFIX_MAILRELAY}" ]; then
    ssh ${SSH_USERNAME}@${HOST} "postconf | grep ^relayhost | grep '\\[${POSTFIX_RELAYHOST}\\]$'" > /dev/null 2>&1
    eval_result "$?" "0" "Postfix is relaying to ${POSTFIX_RELAYHOST}"
  fi

  ssh ${SSH_USERNAME}@${HOST} "grep '^PermitRootLogin no' /etc/ssh/sshd_config" > /dev/null 2>&1
  eval_result "$?" "0" "sshd has PermitRootLogin set to 'no'"

  ssh ${SSH_USERNAME}@${HOST} "grep '^PasswordAuthentication no' /etc/ssh/sshd_config" > /dev/null 2>&1
  eval_result "$?" "0" "sshd has PasswordAuthentication set to 'no'"

  ssh ${SSH_USERNAME}@${HOST} "grep '^Protocol 2' /etc/ssh/sshd_config" > /dev/null 2>&1
  eval_result "$?" "0" "sshd has Protocol set to '2'"

  ssh ${SSH_USERNAME}@${HOST} "grep 'Generated by Chef' /etc/ntp.conf" > /dev/null 2>&1
  eval_result "$?" "0" "ntp is managed by Chef"

  ssh ${SSH_USERNAME}@${HOST} "pidof ntpd" > /dev/null 2>&1
  eval_result "$?" "0" "ntp is running"

  ssh ${SSH_USERNAME}@${HOST} "dpkg-query -s rkhunter" > /dev/null 2>&1
  eval_result "$?" "0" "rkhunter is installed"

  ssh ${SSH_USERNAME}@${HOST} "file /etc/cron.daily/rkhunter" > /dev/null 2>&1
  eval_result "$?" "0" "rkhunter is configured in cron.daily"

  ssh ${SSH_USERNAME}@${HOST} "dpkg-query -s aide" > /dev/null 2>&1
  eval_result "$?" "0" "aide is installed"

  ssh ${SSH_USERNAME}@${HOST} "file /etc/cron.d/aide" > /dev/null 2>&1
  eval_result "$?" "0" "aide is configured in cron.d"

  ssh ${SSH_USERNAME}@${HOST} "dpkg-query -s cron-apt" > /dev/null 2>&1
  eval_result "$?" "0" "cron-apt is installed"

  ssh ${SSH_USERNAME}@${HOST} "file /etc/cron.d/cron-apt" > /dev/null 2>&1
  eval_result "$?" "0" "cron-apt is configured in cron.d"

  ssh ${SSH_USERNAME}@${HOST} "test -s /etc/apt/sources.list" > /dev/null 2>&1
  eval_result "$?" "1" "/etc/apt/sources.list is empty"

  ssh ${SSH_USERNAME}@${HOST} "grep ${APT_MIRROR} /etc/apt/sources.list.d/ubuntu-trusty.list" > /dev/null 2>&1
  eval_result "$?" "0" "/etc/apt/sources.list.d/ubuntu-trusty.list contains ${APT_MIRROR}"

  if [ $(ssh ${SSH_USERNAME}@${HOST} "hostname -f") != "${LOGSERVER}" ]; then
    ssh ${SSH_USERNAME}@${HOST} "grep '*.* :omrelp:${LOGSERVER}:20514' /etc/rsyslog.d/49-remote.conf" > /dev/null 2>&1
    eval_result "$?" "0" "rsyslog is forwarding to ${LOGSERVER} using relp"
  fi
}

infrastructure_checks () {
  HOST=$1

  IP=$(ssh ${SSH_USERNAME}@${HOST} "ifconfig | grep -Eo 'inet (addr:)?([0-9]*\\.){3}[0-9]*' | grep -Eo '([0-9]*\\.){3}[0-9]*' | grep -v '127.0.0.1'")
  if [ $(echo $IP | cut -c1-5) != "${OVERHEAD_SUBNET_PREFIX}" ]; then
    ssh ${SSH_USERNAME}@${HOST} "echo 'moo' | nc -w2 smtp-relay.gmail.com 25" > /dev/null 2>&1
    eval_result "$?" "1" "Outbound port 25 is blocked to external relay"
  fi

  if [ $(ssh ${SSH_USERNAME}@${HOST} "hostname -f") != "${POSTFIX_RELAYHOST}" ]; then
    ssh ${SSH_USERNAME}@${HOST} "echo 'moo' | nc -w2 ${POSTFIX_RELAYHOST} 25" > /dev/null 2>&1
    eval_result "$?" "0" "Outbound port 25 is allowed to ${POSTFIX_RELAYHOST}"
  fi
}

cloudwatch_checks () {
  HOST=$1
  HOST_NAME=$2

  aws cloudwatch describe-alarms --alarm-names ${HOST_NAME}_High-CPUUtilization | grep AlarmName > /dev/null 2>&1
  eval_result "$?" "0" "CPU Utilization is monitored"

  aws cloudwatch describe-alarms --alarm-names ${HOST_NAME}_High-DiskInodeUtilization-/ | grep AlarmName > /dev/null 2>&1
  eval_result "$?" "0" "/ Disk Inode Utilization is monitored"

  aws cloudwatch describe-alarms --alarm-names ${HOST_NAME}_High-DiskSpaceUtilization-/ | grep AlarmName > /dev/null 2>&1
  eval_result "$?" "0" "/ Disk Space Utilization is monitored"

  aws cloudwatch describe-alarms --alarm-names ${HOST_NAME}_High-MemoryUtilization | grep AlarmName > /dev/null 2>&1
  eval_result "$?" "0" "Memory Utilization is monitored"

  aws cloudwatch describe-alarms --alarm-names ${HOST_NAME}_High-StatusCheckFailed | grep AlarmName > /dev/null 2>&1
  eval_result "$?" "0" "EC2 Status is monitored"
}

run_all_checks () {
  HOST=$1
  OUTDIR=$2
  HOST_NAME=$(ssh ${SSH_USERNAME}@${HOST} "hostname -f")
  HOST_NAME_SHORT=$(ssh ${SSH_USERNAME}@${HOST} "hostname")

  echo "[${HOST_NAME}]" > ${OUTDIR}/${HOST}.out
  auth_checks $HOST >> ${OUTDIR}/${HOST}.out
  port_checks $HOST >> ${OUTDIR}/${HOST}.out
  service_checks $HOST >> ${OUTDIR}/${HOST}.out
  infrastructure_checks $HOST >> ${OUTDIR}/${HOST}.out
  cloudwatch_checks $HOST $HOST_NAME_SHORT >> ${OUTDIR}/${HOST}.out

  grep FAIL ${OUTDIR}/${HOST}.out > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo "[FAIL] ${HOST_NAME}"
  else
    echo "[PASS] ${HOST_NAME}"
  fi
}

OUTDIR=`mktemp -d`
echo "* Output going to '${OUTDIR}'"
echo "* Gathering IP addresses from ${VPCS}"
gather_ips $OUTDIR
echo "* Got em! Starting checks..."

for HOST in $(cat ${OUTDIR}/hosts.txt); do
  run_all_checks $HOST $OUTDIR
done

echo "* Complete"

#echo "Removing outdir for testing"
#rm -rf $OUTDIR
