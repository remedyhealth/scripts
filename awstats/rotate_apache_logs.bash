#!/bin/bash
#
# Rotates Apache logs for Awstats consumption
#
#set -x

usage () {
  echo "$0 <site> <server_stub>"
  echo "Ex: $0 mysite.com mysite-nodejs-prod"
}

RSYSLOG_BASE="/logs/rsyslog"
AWSTATS_BASE="/logs/awstats"
LAST_MONTH=$(date --date="`date +%Y-%m-15` -1 month" +'%b')
LAST_MONTHS_YEAR=$(date --date="`date +%Y-%m-15` -1 month" +'%Y')

extract_logs_from_last_month () {
  LOGFILE=$1
  SITE=$2
  SERVER_NAME=$3
  LAST_MONTH=$4
  LAST_MONTHS_YEAR=$5
  OUTPUT="${AWSTATS_BASE}/raw/${SITE}/${SERVER_NAME}_${LAST_MONTH}${LAST_MONTHS_YEAR}_$(basename $LOGFILE)"

  echo "Extracting logs from ${LAST_MONTH} ${LAST_MONTHS_YEAR} to ${OUTPUT}"
  egrep "\[[0-9][0-9]/${LAST_MONTH}/${LAST_MONTHS_YEAR}" $LOGFILE > ${OUTPUT}

  if [ "$?" != "0" ]; then
    echo "Failed to extract logs."
    exit 1
  fi
}

remove_entries_from_active_log () {
  LOGFILE=$1
  LAST_MONTH=$2
  LAST_MONTHS_YEAR=$3

  echo "Removing entries from ${LAST_MONTH} ${LAST_MONTHS_YEAR} in ${LOGFILE}"
  sed -i "/\[[0-9][0-9]\/${LAST_MONTH}\/${LAST_MONTHS_YEAR}/d" $LOGFILE

  if [ "$?" != "0" ]; then
    echo "Failed to remove entries from active log."
    exit 1
  fi
}

SITE=$1
SERVER_STUB=$2

if [ -z "${SITE}" ] || [ -z "${SERVER_STUB}" ]; then
  usage
  exit 1
fi

# Set paths
for SERVER_NAME in `find ${RSYSLOG_BASE} -maxdepth 1 -type d -name "${SERVER_STUB}*" -exec basename {} \;`; do
  for LOGFILE in `find ${RSYSLOG_BASE}/${SERVER_NAME}/www -maxdepth 1 -type f -name "*-access.log"`; do
    extract_logs_from_last_month $LOGFILE $SITE $SERVER_NAME $LAST_MONTH $LAST_MONTHS_YEAR
    remove_entries_from_active_log $LOGFILE $LAST_MONTH $LAST_MONTHS_YEAR
  done
done
