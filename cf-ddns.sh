#!/bin/bash
source /etc/environment
set -o errexit
set -o nounset

# Automatically update cloudflare's dns record, pointing to your public network ip, Dynamic DNS

# curl https://github.com/jjzzorg/cloudflare-api-ddns/blob/172af8742d5f667b305ae2e7afe6c9c94bc24863/cf-ddns.sh > /usr/local/bin/cf-ddns.sh && chmod +x /usr/local/bin/cf-ddns.sh

# run `crontab -e` and add next line:
# */1 * * * * /usr/local/bin/cf-ddns.sh >/dev/null 2>&1
# or you need log:
# */1 * * * * /usr/local/bin/cf-ddns.sh >> /var/log/cf-ddns.log 2>&1



# Usage:
# cf-ddns.sh -k cloudflare-api-key \
#            -u user@example.com \
#            -h host.example.com \     # fqdn of the record you want to update
#            -z example.com \          # If necessary, it will show all zones
#            -t A|AAAA                 # specify ipv4/ipv6,A is for ipv4,AAAA is for ipv6, default: ipv4

# Optional flags:
#            -f false|true \           # force dns update



# default config
##################################################################################################################################
# api-tokens is also called api-key、CFKEY, you can get it from  https://dash.cloudflare.com/profile/api-tokens			#		
CFKEY=1b7f1601e22b7cbd39252333f4afe3e5c0050											 #												
																 #																	
# Username, your email address,eg: user@example.com										 #											
CFUSER=1051239893@qq.com													 #														
																 #																	
# Zone name,your domain name, eg: example.com											 #										    
CFZONE_NAME=jjzz.org														 #														
																 #																	
# Hostname to update, eg: homeserver.example.com										 #											
CFRECORD_NAME=dip.jjzz.org													 #														
																 #																	
##################################################################################################################################

# Record type, A(IPv4)|AAAA(IPv6), default IPv4
CFRECORD_TYPE=A

# Cloudflare TTL for record, between 120 and 86400 seconds
CFTTL=120

# Ignore local file, update ip anyway
FORCE=false





# get parameter
while getopts k:u:h:z:t:f: opts; do
	case $opts in
	k) CFKEY=$OPTARG ;;
	u) CFUSER=$OPTARG ;;
	h) CFRECORD_NAME=$OPTARG ;;
	z) CFZONE_NAME=$OPTARG ;;
	t) CFRECORD_TYPE=$OPTARG ;;
	f) FORCE=$OPTARG ;;
	esac
done

# If the necessary parameters are missing, exit
if [ "$CFKEY" = "" ]; then
	echo "Missing api-key, get at: https://www.cloudflare.com/a/account/my-account"
	echo "and save in $0 or using the -k flag"
	exit 2
fi
if [ "$CFUSER" = "" ]; then
	echo "Missing username, probably your email-address"
	echo "and save in $0 or using the -u flag"
	exit 2
fi
if [ "$CFRECORD_NAME" = "" ]; then
	echo "Missing hostname, what host do you want to update?"
	echo "save in $0 or using the -h flag"
	exit 2
fi

# If the hostname is not a FQDN
if [ "$CFRECORD_NAME" != "$CFZONE_NAME" ] && ! [ -z "${CFRECORD_NAME##*$CFZONE_NAME}" ]; then
	CFRECORD_NAME="$CFRECORD_NAME.$CFZONE_NAME"
	echo " => Hostname is not a FQDN, assuming $CFRECORD_NAME"
fi

# Get the current public network ip and previous public network ip

WAN_IP=`/usr/sbin/ifconfig |sed -n '/^ppp.*/{s/^\([^ ]*\) .*/\1/g;h;: top;n;/^$/b;s/^ \{1,\}inet \(.*\)  netmask.*/\1/g;p}'`

WAN_IP_FILE=$HOME/.cf-wan_ip_$CFRECORD_NAME.txt
if [ -f $WAN_IP_FILE ]; then
	OLD_WAN_IP=`cat $WAN_IP_FILE`
else
	echo "No file, need IP"
	OLD_WAN_IP=""
fi

# The public network ip has not changed, and the -f parameter is not used, exit 
if [ "$WAN_IP" = "$OLD_WAN_IP" ] && [ "$FORCE" = false ]; then
	echo "WAN IP Unchanged, to update anyway use flag -f true"
	exit 0
fi

# Get zone_identifier & record_identifier
ID_FILE=$HOME/.cf-id_$CFRECORD_NAME.txt


if [ -f $ID_FILE ] && [ $(awk 'END{print NR}' $ID_FILE) == 4 ];then
	source $ID_FILE
fi
if [ "${cfzone_name:=nodefined}" = "$CFZONE_NAME" ] \
	&& [ "${cfrecord_name:=nodefined}" = "$CFRECORD_NAME" ]; then
	CFZONE_ID=${cfzone_id:=nodefined}
	CFRECORD_ID=${cfrecord_id:=nodefined}
else
	echo "Updating zone_identifier & record_identifier"
	CFZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$CFZONE_NAME" -H "X-Auth-Email: $CFUSER" -H "X-Auth-Key: $CFKEY" -H "Content-Type: application/json" | grep -Po '(?<="id":")[^"]*' | head -1 )
	CFRECORD_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CFZONE_ID/dns_records?name=$CFRECORD_NAME" -H "X-Auth-Email: $CFUSER" -H "X-Auth-Key: $CFKEY" -H "Content-Type: application/json"  | grep -Po '(?<="id":")[^"]*' | head -1 )
	ID_FILE_TXT="cfzone_id="$CFZONE_ID",cfrecord_id="$CFRECORD_ID",cfzone_name="$CFZONE_NAME",cfrecord_name="$CFRECORD_NAME""
	echo $ID_FILE_TXT|tr ',' "\n"> $ID_FILE
fi

# If WAN is changed, update cloudflare
echo "Updating DNS to $WAN_IP"

RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$CFZONE_ID/dns_records/$CFRECORD_ID" \
-H "X-Auth-Email: $CFUSER" \
-H "X-Auth-Key: $CFKEY" \
-H "Content-Type: application/json" \
--data "{\"type\":\"$CFRECORD_TYPE\",\"name\":\"$CFRECORD_NAME\",\"content\":\"$WAN_IP\", \"ttl\":$CFTTL}")

if [ "$RESPONSE" != "${RESPONSE%success*}" ] && [ "$(echo $RESPONSE | grep "\"success\":true")" != "" ]; then
	echo "Updated succesfuly!"
	echo $WAN_IP > $WAN_IP_FILE
	exit
else
	echo 'Something went wrong :('
	echo "Response: $RESPONSE"
	exit 1
fi
