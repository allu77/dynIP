#!/bin/bash

show_usage() {
	echo "Usage: $0 [OPTIONS] [DNS Entry]" >&2
	echo "" >&2
	echo "Valid OPTIONS" >&2
	echo "  -e CLOUDFLARE_EMAIL" >&2
	echo "  -a CLOUDFLARE_API_KEY" >&2
	echo "  -j JQ_PATH" >&2
	echo "" >&2
	echo "OPTIONS and DNS Entry can either be provided as cmd line options or inside" >&2
	echo "configuration files:" >&2
	echo "  /etc/dynIP" >&2
	echo "  ~/.dynIP" >&2
}

JQ_PATH="/usr/bin/jq"
CLOUDFLARE_EMAIL=""
CLOUDFLARE_API_KEY=""
DNS_ENTRY=""

[ -e /etc/dynIP ] && source /etc/dynIP
[ -e ~/.dynIP ] && source ~/.dynIP

ipFile=/var/lib/dynIP
oldIP="x.x.x.x"


while [ $# -gt 0 ]; do
	case "$1" in
		-e) shift ; CLOUDFLARE_EMAIL="$1" ;; 
		-a) shift ; CLOUDFLARE_API_KEY="$1" ;; 
		-j) shift ; JQ_PATH="$1" ;; 
		-*) 
		    echo "Unknown option $1" >&2
			show_usage
		    exit 1
		    ;;
		*)  break;;	# terminate while loop
	esac
	shift
done

if [ $# -gt 1 ]; then
	echo "Too many parameters"
	show_usage
	exit 1
fi
[ $# -eq 1 ] && DNS_ENTRY="$1"

if [ -z "$CLOUDFLARE_EMAIL" ] || [ -z "$CLOUDFLARE_API_KEY" ] || [ -z "$DNS_ENTRY" ] ; then
	echo "Please provide CloudFlare email, API key and DNS entry to update."
	show_usage
	exit 1
fi

auth_string="-H X-Auth-Email:$CLOUDFLARE_EMAIL -H X-Auth-Key:$CLOUDFLARE_API_KEY"
domain=${DNS_ENTRY#*.}

[ -f "$ipFile" ] && oldIP=$(cat "$ipFile")

echo -n "Checking IP address for entry $DNS_ENTRY... "
newIP=$(curl http://ipv4bot.whatismyipaddress.com/ 2>/dev/null)
echo "$newIP"

# Checking if it's an IP address
checkIP=$(echo $newIP | sed -E 's/[0-9]+/x/g')
if [ "$checkIP" != "x.x.x.x" ]; then
	echo "What's my IP returned a non IP address value. Exiting." >2
	exit 1
fi


if [ "$newIP" != "$oldIP" ]; then
	echo -n "Getting zone ID for domain $domain... "
	zoneJson=$(curl -X GET https://api.cloudflare.com/client/v4/zones?name=$domain $auth_string 2>/dev/null)
	if [ $(echo "$zoneJson" | $JQ_PATH ".success") != true ]; then
		echo -n "Cloudflare API failed: " >2
		echo $zoneJson | $JQ_PATH -r ".errors[0].message" >2
		exit 1
	fi

	zoneId=$(echo $zoneJson | $JQ_PATH -r ".result[0].id")
	if [ -z "$zoneId" ] || [ "$zoneId"  == "null" ]; then
		echo "Failed! Returned zone id $zoneId" >2
		exit 1;
	fi 

	echo "$zoneId"

	echo -n "Getting existing entry for $DNS_ENTRY... "
	entryJSon=$(curl -X GET https://api.cloudflare.com/client/v4/zones/$zoneId/dns_records?name=$DNS_ENTRY $auth_string 2>/dev/null)
	if [ $(echo "$entryJSon" | $JQ_PATH ".success") != true ]; then
		echo -n "Cloudflare API failed: " >2
		echo $entryJSon | $JQ_PATH -r ".errors[0].message" >2
	fi

	entryResult=$(echo "$entryJSon" | $JQ_PATH ".result[0]")

	entryId=$(echo "$entryResult" | $JQ_PATH -r ".id")

	if [ -z "$entryId" ] || [ "$entryId" == "null" ]; then
		echo "Failed! Returned entry id $entryId" >2
		exit 1;
	fi 

	echo "ID $entryId"

	echo -n "Updating $DNS_ENTRY entry... "
	newEntry=$(echo "$entryResult" | $JQ_PATH ".content = \"$newIP\"")
	result=$(curl -X PUT "https://api.cloudflare.com/client/v4/zones/$zoneId/dns_records/$entryId" $auth_string -H "Content-Type: application/json" --data "$newEntry" 2>/dev/null)
	if [ $(echo "$result" | $JQ_PATH ".success") != true ]; then
		echo -n "Cloudflare API failed: " >2
		echo $zoneJson | $JQ_PATH -r ".errors[0].message" >2
		exit 1
	fi
	echo "Done!"

	echo -n "Saving new IP address in $ipFile... "
	if ! echo $newIP 2>/dev/null 1>$ipFile; then
		echo "Save Failed!" >2
		exit 1
	fi
	echo "Done."
fi

exit 0
