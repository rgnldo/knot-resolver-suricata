#!/bin/bash

echo -e "\e[96m
+------------------------- Adblock Unbound --------------------------+
|                                                                    |
|             Ads/tracker block for Unbound by @rgnldo               |
|                                                                    |
+--------------------------------------------------------------------+\033[0;39m"
sleep 2s
echo "Checking FW version"
sleep 2s
echo "FW Version; $(nvram get buildno)_$(nvram get extendno) ($(uname -v | awk '{printf "%s %s %s\n", $5, $6, $9}')) ($(uname -r))"
sleep 2s

tempoutlist="/opt/var/lib/unbound/adblock/adlist.tmp"
outlist='/opt/var/lib/unbound/adblock/tmp.host'
finalist='/opt/var/lib/unbound/adblock/tmp.finalhost'
permlist='/opt/var/lib/unbound/adblock/permlist'
adlist='/opt/var/lib/unbound/zones/gen_adblock.rpz'
blockhost='/opt/var/lib/unbound/adblock/blockhost'
loadlist='/opt/var/lib/unbound/adblock/loadservers'
statsFile="/opt/var/lib/unbound/adblock/stats.txt"

echo -n "Create necessary files... "

if [ -n "$blockhost" ];then touch -f $blockhost
   fi
if [ -n "$permlist" ];then touch -f $permlist
   fi

sleep 2s
echo -e  -n "[\033[01;32m  OK  \033[0;39m]"
echo

echo -n "Removing possible temporary files... "
[ -f $tempoutlist ] && rm -f $tempoutlist
[ -f $outlist ] && rm -f $outlist
[ -f $finalist ] && rm -f $finalist
[ -f $loadlist ] && rm -f $loadlist

sleep 2s
echo -e  -n "[\033[01;32m  OK  \033[0;39m]"
echo

hosts='https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts
       https://raw.githubusercontent.com/rgnldo/knot-resolver-suricata/master/hosts
       https://raw.githubusercontent.com/HexxiumCreations/threat-list/gh-pages/domainsonly
       https://isc.sans.edu/feeds/suspiciousdomains_Medium.txt
       https://raw.githubusercontent.com/hectorm/hmirror/master/data/spam404.com/list.txt
       https://raw.githubusercontent.com/hectorm/hmirror/master/data/ublock/list.txt
       https://raw.githubusercontent.com/hectorm/hmirror/master/data/ublock-badware/list.txt
       https://raw.githubusercontent.com/hectorm/hmirror/master/data/ublock-privacy/list.txt
       https://raw.githubusercontent.com/hectorm/hmirror/master/data/dshield.org-high/list.txt
       https://raw.githubusercontent.com/hectorm/hmirror/master/data/easylist/list.txt
       https://raw.githubusercontent.com/hectorm/hmirror/master/data/easyprivacy/list.txt
       https://raw.githubusercontent.com/hectorm/hmirror/master/data/adblock-nocoin-list/list.txt
       https://raw.githubusercontent.com/hectorm/hmirror/master/data/disconnect.me-ad/list.txt
       https://raw.githubusercontent.com/hectorm/hmirror/master/data/disconnect.me-malvertising/list.txt
       https://raw.githubusercontent.com/hectorm/hmirror/master/data/disconnect.me-malware/list.txt
       https://raw.githubusercontent.com/hectorm/hmirror/master/data/disconnect.me-tracking/list.txt
       https://raw.githubusercontent.com/hectorm/hmirror/master/data/zerodot1-coinblockerlists-browser/list.txt
       https://raw.githubusercontent.com/hectorm/hmirror/master/data/matomo.org-spammers/list.txt
       https://raw.githubusercontent.com/hectorm/hmirror/master/data/adguard-simplified/list.txt
       https://raw.githubusercontent.com/hectorm/hmirror/master/data/eth-phishing-detect/list.txt
       https://raw.githubusercontent.com/hectorm/hmirror/master/data/antipopads/list.txt
       https://raw.githubusercontent.com/hectorm/hmirror/master/data/phishing.army/list.txt
       https://raw.githubusercontent.com/hectorm/hmirror/master/data/hostsvn/list.txt
       https://raw.githubusercontent.com/hectorm/hmirror/master/data/pgl.yoyo.org/list.txt'

permilist='https://raw.githubusercontent.com/anudeepND/whitelist/master/domains/whitelist.txt
           https://raw.githubusercontent.com/anudeepND/whitelist/master/domains/optional-list.txt
           https://raw.githubusercontent.com/rgnldo/knot-resolver-suricata/master/permlist'

echo -n "Setting up block list downloader... "
sleep 2s
echo -e  -n "[\033[01;32m  OK  \033[0;39m]"
echo
echo -n "Get hosts list... "
curl -s $hosts | grep -o '^[^#]*' | grep -v "::1" | grep -v "0.0.0.0 0.0.0.0" | sed '/^$/d' | sed 's/\ /\\ /g' | sed 's/[A-Z]/\L&/g' | awk '{print $NF}' | grep -o '^[^\\]*' | grep -o '^[^\\$]*' | uniq | sort -f >> $tempoutlist
sleep 2s
echo -e  -n "[\033[01;32m  OK  \033[0;39m]"
echo
echo -n "Get permilist... "
curl -s $permilist | grep -o '^[^#]*' | grep -v "::1" | grep -v "0.0.0.0 0.0.0.0" | sed '/^$/d' | sed 's/\ /\\ /g' | sed 's/[A-Z]/\L&/g' | awk '{print $NF}' | grep -o '^[^\\]*' | grep -o '^[^\\$]*' | uniq | sort -f > $permlist
sleep 2s
echo -e  -n "[\033[01;32m  OK  \033[0;39m]"
echo
echo -n "Combining User Custom block host... "
cat $blockhost | awk '{for(i=NF; i > 1; i--) printf "%s.", $i; print $1}' | uniq | sort -f >> $tempoutlist
sleep 3s
echo -e  -n "[\033[01;32m  OK  \033[0;39m]"
echo
numberOfAdsBlocked=$(wc -l < $tempoutlist)
echo -e "\e[31;1m$numberOfAdsBlocked\e[31;1m \e[37;1mdomains compiled\033[0;39m"
sleep 3s
echo -n "Edit User Custon list of allowed domains... "
awk 'NR==FNR{a[$0];next} !($0 in a) {print $NF}'  $permlist $tempoutlist | sort -u > $outlist
sleep 3s
echo -e  -n "[\033[01;32m  OK  \033[0;39m]"
echo
echo -n "Removing duplicate formatting from the domain list... "
cat $outlist | awk '{for(i=NF; i > 1; i--) printf "%s.", $i; print $1}' | uniq | sort -f | sed '/^$/d' > $finalist
sleep 2s
echo -e  -n "[\033[01;32m  OK  \033[0;39m]"
echo
echo -n "Generating Unbound adlist... "
sed -- 's/$/ CNAME ./g' $finalist > $adlist
sleep 3s
echo -e  -n "[\033[01;32m  OK  \033[0;39m]"
echo
numberOfAdunbound=$(wc -l < $adlist)
echo -e "\e[31;1m$numberOfAdunbound\e[31;1m \e[37;1msuspicious and blocked domains\033[0;39m"
echo " Number of adblocked (ads/malware/tracker) and blacklisted hosts: $numberOfAdunbound" > $statsFile
echo " Last updated: $(date +"%c")" >> $statsFile
sleep 3s
echo "Restarting services..."
unbound-control reload
sleep 3s
echo -e  -n "[\033[01;32m  OK  \033[0;39m]"
echo
echo -n "Removing temporary files... "
[ -f $tempoutlist ] && rm -f $tempoutlist
[ -f $outlist ] && rm -f $outlist
[ -f $finalist ] && rm -f $finalist
[ -f $loadlist ] && rm -f $loadlist

sleep 3s
echo -e  -n "[\033[01;32m  OK  \033[0;39m]"
echo
sleep 3s
echo -e  -n "[\033[01;32m  OK  \033[0;39m]"
echo
if [ -n "$(pidof unbound)" ];then
  echo -n "No problems! Unbound server "
  echo -e  -n "[\033[01;32m  alive  \033[0;39m]"
  echo
  else
  echo -n "Problem! Unbound server "
  echo -e  -n "[\e[31;1m  dead  \033[0;39m]"
  echo
fi
