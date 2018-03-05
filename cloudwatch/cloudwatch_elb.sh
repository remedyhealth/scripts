#!/bin/bash

if [ ! -f ~/.baseline_check.cfg ]; then
  echo "~/.baseline_check.cfg does not exist!"
  exit 1
fi

. ~/.baseline_check.cfg

ELBNAME=$1
ENVIRONMENT=production
LATENCY_THRESHOLD=$2

if [ -z "${ELBNAME}" ] || [ -z "${LATENCY_THRESHOLD}" ]; then
  echo "ELBNAME and LATENCY_THRESHOLD must be set"
  echo "./cloudwatch.sh <elbname> <latency>"
  exit 1
fi

if [ "$ENVIRONMENT" == "production" ]; then
  SNS_TOPIC=$PAGERDUTY_PROD
else
  SNS_TOPIC=$PAGERDUTY_NOTPROD
fi

# Create CloudWatch Alarms
aws cloudwatch put-metric-alarm \
  --alarm-name elb-${ELBNAME}_High-BackendConnectionErrors \
  --ok-actions ${SNS_TOPIC} \
  --alarm-actions ${SNS_TOPIC} \
  --alarm-description "High Backend Connection Errors on ELB ${ELBNAME}" \
  --statistic Sum \
  --namespace AWS/ELB \
  --metric-name BackendConnectionErrors \
  --period 300 \
  --evaluation-periods 1 \
  --threshold 0 \
  --comparison-operator GreaterThanThreshold \
  --dimensions "Name=LoadBalancerName,Value=${ELBNAME}"

aws cloudwatch put-metric-alarm \
  --alarm-name elb-${ELBNAME}_High-Latency \
  --ok-actions ${SNS_TOPIC} \
  --alarm-actions ${SNS_TOPIC} \
  --alarm-description "High Latency on ELB ${ELBNAME}" \
  --statistic Average \
  --namespace AWS/ELB \
  --metric-name Latency \
  --period 300 \
  --evaluation-periods 3 \
  --threshold ${LATENCY_THRESHOLD} \
  --comparison-operator GreaterThanThreshold \
  --dimensions "Name=LoadBalancerName,Value=${ELBNAME}"
