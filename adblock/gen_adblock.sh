#!/bin/bash
destinationIP="0.0.0.0"
tempoutlist="/opt/var/lib/unbound/adblock/adlist.tmp"
outlist='/opt/var/lib/unbound/adblock/tmp.host'
finalist='/opt/var/lib/unbound/adblock/tmp.finalhost'
permlist='/opt/var/lib/unbound/adblock/permlist'
adlist='/opt/var/lib/unbound/adblock/adservers'

echo "Removing possible temporary files.."
[ -f $tempoutlist ] && rm -f $tempoutlist
[ -f $outlist ] && rm -f $outlist
[ -f $finalist ] && rm -f $finalist

echo "Dowloading StevenBlack Adlist..."
curl --progress-bar https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts | grep -v "#" | grep -v "::1" | grep -v "0.0.0.0 0.0.0.0" | sed '/^$/d' | sed 's/\ /\\ /g' | awk '{print $2}' | grep -v '^\\' | grep -v '\\$'| sort >> $tempoutlist
echo "Dowloading Disconnect.me 1 Adlist..."
curl --progress-bar https://s3.amazonaws.com/lists.disconnect.me/simple_ad.txt | grep -v "#" | grep -v "::1" | grep -v "0.0.0.0 0.0.0.0" | sed '/^$/d' | sed 's/\ /\\ /g' | awk '{print $2}' | grep -v '^\\' | grep -v '\\$'| sort >> $tempoutlist
echo "Dowloading Disconnect.me 2 Adlist..."
curl --progress-bar https://s3.amazonaws.com/lists.disconnect.me/simple_malvertising.txt | grep -v "#" | grep -v "::1" | grep -v "0.0.0.0 0.0.0.0" | sed '/^$/d' | sed 's/\ /\\ /g' | awk '{print $2}' | grep -v '^\\' | grep -v '\\$'| sort >> $tempoutlist
echo "Dowloading Disconnect.me 3 Adlist..."
curl --progress-bar https://s3.amazonaws.com/lists.disconnect.me/simple_malware.txt | grep -v "#" | grep -v "::1" | grep -v "0.0.0.0 0.0.0.0" | sed '/^$/d' | sed 's/\ /\\ /g' | awk '{print $2}' | grep -v '^\\' | grep -v '\\$'| sort >> $tempoutlist
echo "Dowloading Disconnect.me 4 Adlist..."
curl --progress-bar https://s3.amazonaws.com/lists.disconnect.me/simple_tracking.txt | grep -v "#" | grep -v "::1" | grep -v "0.0.0.0 0.0.0.0" | sed '/^$/d' | sed 's/\ /\\ /g' | awk '{print $2}' | grep -v '^\\' | grep -v '\\$'| sort >> $tempoutlist
echo "Dowloading antipopads Adlist..."
curl --progress-bar https://raw.githubusercontent.com/Yhonay/antipopads/master/hosts | grep -v "#" | grep -v "::1" | grep -v "0.0.0.0 0.0.0.0" | sed '/^$/d' | sed 's/\ /\\ /g' | awk '{print $2}' | grep -v '^\\' | grep -v '\\$'| sort >> $tempoutlist
echo "Dowloading No Spam Adlist..."
curl --progress-bar https://hosts-file.net/grm.txt | grep -v "#" | grep -v "::1" | grep -v "0.0.0.0 0.0.0.0" | sed '/^$/d' | sed 's/\ /\\ /g' | awk '{print $2}' | grep -v '^\\' | grep -v '\\$'| sort >> $tempoutlist
echo "Dowloading No Coin Adlist..."
curl --progress-bar https://raw.githubusercontent.com/hoshsadiq/adblock-nocoin-list/master/hosts.txt | grep -v "#" | grep -v "::1" | grep -v "0.0.0.0 0.0.0.0" | sed '/^$/d' | sed 's/\ /\\ /g' | awk '{print $2}' | grep -v '^\\' | grep -v '\\$'| sort >> $tempoutlist

echo "Combining User Custom block host..."
cat /opt/var/lib/unbound/adblock/blockhost >> $tempoutlist

echo "Removing duplicate formatting from the domain list..."
cat $tempoutlist | sed -r -e 's/[[:space:]]+/\t/g' | sed -e 's/\t*#.*$//g' | sed -e 's/[^a-zA-Z0-9\.\_\t\-]//g' | sed -e 's/\t$//g' | sed -e '/^#/d' | sort -u | sed '/^$/d' | awk -v "IP=$destinationIP" '{sub(/\r$/,""); print IP" "$0}' > $outlist
numberOfAdsBlocked=$(cat $outlist | wc -l | sed 's/^[ \t]*//')
echo "$numberOfAdsBlocked domains compiled"

echo "Edit User Custon list of allowed domains..."
fgrep -vf $permlist $outlist  > $finalist

echo "Generating Unbound adlist....."
cat $finalist | grep '^0\.0\.0\.0' | awk '{print "local-zone: \""$2"\" always_nxdomain"}' > $adlist
numberOfAdsBlocked=$(cat $adlist | wc -l | sed 's/^[ \t]*//')
echo "$numberOfAdsBlocked suspicious and blocked domains"

echo "Removing temporary files..."
[ -f $tempoutlist ] && rm -f $tempoutlist
[ -f $outlist ] && rm -f $outlist
[ -f $finalist ] && rm -f $finalist

echo "Removing log's files..."
[ -f /opt/var/lib/unbound/unbound.log ] && rm -f /opt/var/lib/unbound/unbound.log
echo "Restarting DNS servers..."
/opt/etc/init.d/S61unbound restart
