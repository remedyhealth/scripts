#!/bin/bash

if [ ! -f ~/.baseline_check.cfg ]; then
  echo "~/.baseline_check.cfg does not exist!"
  exit 1
fi

. ~/.baseline_check.cfg

RDSNAME=$1
ENVIRONMENT=$2

if [ -z "${RDSNAME}" ] || [ -z "${ENVIRONMENT}" ]; then
  echo "RDSNAME and ENVIRONMENT must be set"
  echo "./cloudwatch.sh <rdsname> <environment>"
  exit 1
fi

if [ "$ENVIRONMENT" == "production" ]; then
  SNS_TOPIC=$PAGERDUTY_PROD
else
  SNS_TOPIC=$PAGERDUTY_NOTPROD
fi

# Create CloudWatch Alarms
aws cloudwatch put-metric-alarm \
  --alarm-name ${RDSNAME}_High-CPUUtilization \
  --ok-actions ${SNS_TOPIC} \
  --alarm-actions ${SNS_TOPIC} \
  --alarm-description "High CPU Utilization on ${RDSNAME}" \
  --statistic Average \
  --namespace AWS/RDS \
  --metric-name CPUUtilization \
  --period 300 \
  --evaluation-periods 2 \
  --threshold 75 \
  --comparison-operator GreaterThanThreshold \
  --dimensions "Name=DBInstanceIdentifier,Value=${RDSNAME}"

aws cloudwatch put-metric-alarm \
  --alarm-name ${RDSNAME}_High-DatabaseConnections \
  --ok-actions ${SNS_TOPIC} \
  --alarm-actions ${SNS_TOPIC} \
  --alarm-description "High Database Connections on ${RDSNAME}" \
  --statistic Average \
  --namespace AWS/RDS \
  --metric-name DatabaseConnections \
  --period 300 \
  --evaluation-periods 2 \
  --threshold 30 \
  --comparison-operator GreaterThanThreshold \
  --dimensions "Name=DBInstanceIdentifier,Value=${RDSNAME}"
