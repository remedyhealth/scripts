#!/bin/sh
#
# Deploys and Monitors an OpsWorks deployment until it completes
#
# Usage: opsworks_deploy.bash <stackid> <appid>
#
# Requires: AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY must be set
#
#set -x

usage () {
  echo "$0 <stackid> <appid>"
}

start_deploy () {
  STACK_ID=$1
  APP_ID=$2

  aws --region='us-east-1' opsworks create-deployment --stack-id=${STACK_ID} --app-id=${APP_ID} --comment="Codeship Build ${CI_BUILD_NUMBER}" --command='{"Name": "deploy"}' | grep DeploymentId | awk -F\" '{print $4}'
}

monitor_deploy () {
  DEPLOYMENT_ID=$1

  DEPLOYMENT_RESULT=`aws --region='us-east-1' opsworks describe-deployments --deployment-id=${DEPLOYMENT_ID} | grep Status | awk -F\" '{print $4}' | egrep '(successful|failed)'`
  while [ $? -ne 0 ]; do
    sleep 10
    DEPLOYMENT_RESULT=`aws --region='us-east-1' opsworks describe-deployments --deployment-id=${DEPLOYMENT_ID} | grep Status | awk -F\" '{print $4}' | egrep '(successful|failed)'`
  done
  echo $DEPLOYMENT_RESULT
}

evaluate_result () {
  DEPLOYMENT_RESULT="$1"
  STACKNAME="$2"
  APPNAME="$3"

  echo "Deployment '${DEPLOYMENT_ID}' completed with status '${DEPLOYMENT_RESULT}'."

  if [ ! -z "${SLACK_WEBHOOK_URL}" ]; then
    echo "Notifying Slack Webhook"
    curl --data "payload={\"text\": \"*$STACKNAME* *$APPNAME* deployment triggered by *CodeShip* was *$DEPLOYMENT_RESULT*\"}" "$SLACK_WEBHOOK_URL"
  fi

  if [ "${DEPLOYMENT_RESULT}" == "successful" ]; then
    exit 0
  else
    exit 1
  fi
}

STACK_ID=$1
APP_ID=$2

if [ -z "${STACK_ID}" ] || [ -z "${APP_ID}" ]; then
  usage
  exit 1
fi

if [ -z "${AWS_ACCESS_KEY_ID}" ] || [ -z "${SECRET_ACCESS_KEY}" ]; then
  echo "AWS_ACCESS_KEY_ID and SECRET_ACCCESS_KEY must be set"
  exit 1
fi

STACKNAME=`aws --region='us-east-1' opsworks describe-stacks --stack-id $STACK_ID | grep Name | grep -v Chef | awk -F\" '{print $4}'`
APPNAME=`aws --region='us-east-1' opsworks describe-apps --app-id $APP_ID | grep Shortname | awk -F\" '{print $4}'`
DEPLOYMENT_ID=$(start_deploy $STACK_ID $APP_ID)
echo "Deployment '${DEPLOYMENT_ID}' started."
DEPLOYMENT_RESULT=$(monitor_deploy $DEPLOYMENT_ID)
evaluate_result "$DEPLOYMENT_RESULT" "$STACKNAME" "$APPNAME"
