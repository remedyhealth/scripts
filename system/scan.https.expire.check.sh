#!/bin/bash
#
# alerts
# - to slack $URL_SLACKHOOK 
# - when SSL cert is about to exire in $ALERT_DAYS days
# - on any domain in $LISTSITE_W_SSL list
#
# usage: ./scan.https.expire.check.sh [optional_slack_webhook]
#

LISTSITE_W_SSL="services.rmdy.hm www.healthcentral.com www.thebody.com www.thebodypro.com"
# Ron: "https://hooks.slack.com/services/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"
# Saurav: "https://hooks.slack.com/services/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"
# Paul: "https://hooks.slack.com/services/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"
URL_SLACKHOOK=${1:-"https://hooks.slack.com/services/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"}
O_SSL_DATE_FMT="%b %d %T %Y %Z"
ALERT_DAYS=30
ONLY_ALERTS=1

TOTAL_SCANNED=0
TOTAL_SCANNED_ALERTS=0
LIST_OF_ALERTS=""

openssl_getDates()
{
  domain=$1
  whatDate=$2
  echo | openssl s_client -servername $domain -connect $i:443 2>/dev/null | openssl x509 -noout -dates | grep $whatDate | cut -d'=' -f2
}

convert_openssl_date() {
  whatDate=$1
  echo $(TZ=America/New_York date -j -f "${O_SSL_DATE_FMT}" "${whatDate}" +"%Y %m %d %T")
}

send_w_slackhook() {
	DAYS_LEFT=$1
	DAYS_EXPIRE=$2
	THE_SITE=$3

	if [ "${DAYS_LEFT}" -le "${ALERT_DAYS}" ]; then
		COLOR="danger"
	else
		COLOR="good"
	fi
	SLACK_TEXT="SSL CERT: ${THE_SITE}"

	PAYLOAD="{
	  \"attachments\": [
	    {
	      \"username\": \"SSL Watcher\",
	      \"text\": \"SSL Watcher for ${THE_SITE}\",
	      \"color\": \"$COLOR\",
	      \"mrkdwn_in\": [\"text\"],
	      \"fields\": [
	        { \"title\": \"Expire Date\", \"value\": \"$DAYS_EXPIRE\", \"short\": true },
	        { \"title\": \"Days Left\", \"value\": \"$DAYS_LEFT\", \"short\": true }
	      ]
	    }
	  ]
	}"
	curl -s -X POST --data-urlencode "payload=$PAYLOAD" $URL_SLACKHOOK > /dev/null
}

for i in $LISTSITE_W_SSL; do
  REGISTERED_ON=$( openssl_getDates $i "notBefore" )
  EXPIRES_ON=$( openssl_getDates $i "notAfter" )
  EXPIRES_ON_SEC=$(TZ=America/New_York date -j -f "${O_SSL_DATE_FMT}"  "$EXPIRES_ON" +"%s")
  CUR_SEC=$(date +"%s") 
  DIFF_SEC=$(($EXPIRES_ON_SEC-$CUR_SEC))
  DIFF_DAYS=$(($DIFF_SEC/86400))

  echo "---> ${i}";
  echo reg: $( convert_openssl_date "${REGISTERED_ON}" )
  echo exp: $( convert_openssl_date "${EXPIRES_ON}" )

  echo "Expires IN ${DIFF_DAYS} Days"
  let "TOTAL_SCANNED+=1"
  if [ "${DIFF_DAYS}" -le "${ALERT_DAYS}" ]; then
  	echo "BAD"
  	let "TOTAL_SCANNED_ALERTS+=1"
  	LIST_OF_ALERTS="${LIST_OF_ALERTS} ${i}"
  	send_w_slackhook $DIFF_DAYS "${EXPIRES_ON}" "${i}"
  elif [ $ONLY_ALERTS -lt 1 ]; then
  	echo "GOOD"
  	send_w_slackhook $DIFF_DAYS "${EXPIRES_ON}" "${i}"
  fi
done
echo "SCANNED (${TOTAL_SCANNED}) total found (${TOTAL_SCANNED_ALERTS}) about to expire"
[ -z "${LIST_OF_ALERTS}" ] || printf " - %s\n" $LIST_OF_ALERTS