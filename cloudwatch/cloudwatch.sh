#!/bin/bash

if [ ! -f ~/.baseline_check.cfg ]; then
  echo "~/.baseline_check.cfg does not exist!"
  exit 1
fi

. ~/.baseline_check.cfg

NODENAME=$1
ENVIRONMENT=$2
INSTANCE_ID=$3
DISKS=$4

if [ -z "${NODENAME}" ] || [ -z "${ENVIRONMENT}" ] || [ -z "${INSTANCE_ID}" ]; then
  echo "NODENAME, ENVIRONMENT, and INSTANCE_ID must be set"
  echo "./cloudwatch.sh <nodename> <environment> <instance_id> <disks>"
  echo "eg: <disks> = /:/dev/xvda1,/mnt/backups/dev/xvdh"
  exit 1
fi

if [ -z "${DISKS}" ]; then
  DISKS="/:/dev/xvda1"
fi

if [ "$ENVIRONMENT" == "production" ]; then
  SNS_TOPIC=$PAGERDUTY_PROD
else
  SNS_TOPIC=$PAGERDUTY_NOTPROD
fi

# Create CloudWatch Alarms
aws cloudwatch put-metric-alarm \
  --alarm-name ${NODENAME}_High-CPUUtilization \
  --ok-actions ${SNS_TOPIC} \
  --alarm-actions ${SNS_TOPIC} \
  --alarm-description "High CPU Utilization on ${NODENAME}" \
  --statistic Average \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --period 300 \
  --evaluation-periods 2 \
  --threshold 75 \
  --comparison-operator GreaterThanThreshold \
  --dimensions "Name=InstanceId,Value=${INSTANCE_ID}"

for disk in $(echo $DISKS | sed "s/,/ /g")
do
  MOUNT=$(echo $disk | awk -F: '{print $1}')
  DEVICE=$(echo $disk | awk -F: '{print $2}')

  aws cloudwatch put-metric-alarm \
  --alarm-name ${NODENAME}_High-DiskInodeUtilization-${MOUNT} \
  --ok-actions ${SNS_TOPIC} \
  --alarm-actions ${SNS_TOPIC} \
  --alarm-description "High Disk Inode Utilization for ${MOUNT} on ${NODENAME}" \
  --statistic Average \
  --namespace System/Linux \
  --metric-name DiskInodeUtilization \
  --period 300 \
  --evaluation-periods 2 \
  --threshold 90 \
  --comparison-operator GreaterThanThreshold \
  --dimensions "Name=InstanceId,Value=${INSTANCE_ID}" "Name=MountPath,Value=${MOUNT}" "Name=Filesystem,Value=${DEVICE}"

  aws cloudwatch put-metric-alarm \
  --alarm-name ${NODENAME}_High-DiskSpaceUtilization-${MOUNT} \
  --ok-actions ${SNS_TOPIC} \
  --alarm-actions ${SNS_TOPIC} \
  --alarm-description "High Disk Space Utilization for / on ${NODENAME}" \
  --statistic Average \
  --namespace System/Linux \
  --metric-name DiskSpaceUtilization \
  --period 300 \
  --evaluation-periods 2 \
  --threshold 90 \
  --comparison-operator GreaterThanThreshold \
  --dimensions "Name=InstanceId,Value=${INSTANCE_ID}" "Name=MountPath,Value=${MOUNT}" "Name=Filesystem,Value=${DEVICE}"
done

aws cloudwatch put-metric-alarm \
  --alarm-name ${NODENAME}_High-MemoryUtilization \
  --ok-actions ${SNS_TOPIC} \
  --alarm-actions ${SNS_TOPIC} \
  --alarm-description "High Memory Utilization on ${NODENAME}" \
  --statistic Average \
  --namespace System/Linux \
  --metric-name MemoryUtilization \
  --period 300 \
  --evaluation-periods 2 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --dimensions "Name=InstanceId,Value=${INSTANCE_ID}"

aws cloudwatch put-metric-alarm \
  --alarm-name ${NODENAME}_High-StatusCheckFailed \
  --ok-actions ${SNS_TOPIC} \
  --alarm-actions ${SNS_TOPIC} \
  --alarm-description "Status Check Failed on ${NODENAME}" \
  --statistic Average \
  --namespace AWS/EC2 \
  --metric-name StatusCheckFailed \
  --period 60 \
  --evaluation-periods 1 \
  --threshold 0 \
  --comparison-operator GreaterThanThreshold \
  --dimensions "Name=InstanceId,Value=${INSTANCE_ID}"
