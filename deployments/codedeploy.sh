#!/bin/sh
#
# Deploys and Monitors a CodeDeploy deployment until it completes
#
# Usage: codedeploy.sh <ApplicationName> <DeploymentGroup> <S3 Bucket> <S3 Key>
#
# Requires: AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY must be set
#
#set -x

usage () {
  echo "$0 <ApplicationName> <DeploymentGroup> <S3Bucket> <S3Key>"
}

start_deploy () {
  APPLICATION_NAME=$1
  DEPLOYMENT_GROUP=$2
  S3_BUCKET=$3
  S3_KEY=$3

  aws deploy create-deployment --application-name "${APPLICATION_NAME}" \
                               --deployment-group-name "${DEPLOYMENT_GROUP}" \
                               --s3-location "bucket=${S3_BUCKET},bundleType=tgz,key=${S3_KEY}" \
                               --description "Codeship Build ${CI_BUILD_NUMBER}" | grep deploymentId | awk -F\" '{print $4}'
}

monitor_deploy () {
  DEPLOYMENT_ID=$1

  DEPLOYMENT_RESULT=`aws deploy get-deployment --deployment-id=${DEPLOYMENT_ID} | grep status | awk -F\" '{print $4}' | egrep '(Successful|Failed)'`
  while [ $? -ne 0 ]; do
    sleep 10
    DEPLOYMENT_RESULT=`aws deploy get-deployment --deployment-id=${DEPLOYMENT_ID} | grep status | awk -F\" '{print $4}' | egrep '(Successful|Failed)'`
  done
  echo $DEPLOYMENT_RESULT
}

evaluate_result () {
  DEPLOYMENT_RESULT="$1"
  APPLICATION_NAME="$2"
  DEPLOYMENT_GROUP="$3"

  echo "Deployment '${DEPLOYMENT_ID}' completed with status '${DEPLOYMENT_RESULT}'."

  if [ ! -z "${SLACK_WEBHOOK_URL}" ]; then
    echo "Notifying Slack Webhook"
    curl --data "payload={\"text\": \"*$DEPLOYMENT_GROUP* *$APPLICATION_NAME* deployment triggered by *CodeDeploy* was *$DEPLOYMENT_RESULT*\"}" "$SLACK_WEBHOOK_URL"
  fi

  if [ "${DEPLOYMENT_RESULT}" == "Successful" ]; then
    exit 0
  else
    exit 1
  fi
}

APPLICATION_NAME=$1
DEPLOYMENT_GROUP=$2
S3_BUCKET=$3
S3_KEY=$3

if [ -z "${APPLICATION_NAME}" ] || [ -z "${DEPLOYMENT_GROUP}" ] || [ -z "${S3_BUCKET}" ] || [ -z "${S3_KEY}" ]; then
  usage
  exit 1
fi

if [ -z "${AWS_ACCESS_KEY_ID}" ] || [ -z "${AWS_SECRET_ACCESS_KEY}" ]; then
  echo "AWS_ACCESS_KEY_ID and AWS_SECRET_ACCCESS_KEY must be set"
  exit 1
fi

DEPLOYMENT_ID=$(start_deploy ${APPLICATION_NAME} ${DEPLOYMENT_GROUP} ${S3_BUCKET} ${S3_KEY})
echo "Deployment '${DEPLOYMENT_ID}' started."
DEPLOYMENT_RESULT=$(monitor_deploy ${DEPLOYMENT_ID})
evaluate_result "$DEPLOYMENT_RESULT" "$APPLICATION_NAME" "$DEPLOYMENT_GROUP"
