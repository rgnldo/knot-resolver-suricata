#!/bin/sh
####################################################################################################
# Script: install_unbound.sh
# Original Author: Martineau
# Maintainer:
# Last Updated Date: 18-Dec-2019
#
# Description:
#  Install the unbound DNS over TLS resolver package from Entware on Asuswrt-Merlin firmware.
#  See https://github.com/rgnldo/Unbound-Asuswrt-Merlin for a description of system changes
#
# Acknowledgement:
#  Chk_Entware function provided by Martineau.
#  Test team:
#  Contributors: rgnldo (Xentrk for this script template, thelonelycoder)
#
#
####################################################################################################
export PATH=/sbin:/bin:/usr/sbin:/usr/bin$PATH
logger -t "($(basename "$0"))" "$$ Starting Script Execution ($(if [ -n "$1" ]; then echo "$1"; else echo "menu"; fi))"
VERSION="1.06"
GIT_REPO="unbound-Asuswrt-Merlin"
GITHUB_DIR="https://raw.githubusercontent.com/rgnldo/$GIT_REPO/master"


# Uncomment the line below for debugging
#set -x

Say(){
   echo -e $$ $@ | logger -st "($(basename $0))"
}
SayT(){
   echo -e $$ $@ | logger -t "($(basename $0))"
}
# shellcheck disable=SC2034
ANSIColours() {

	cRESET="\e[0m";cBLA="\e[30m";cRED="\e[31m";cGRE="\e[32m";cYEL="\e[33m";cBLU="\e[34m";cMAG="\e[35m";cCYA="\e[36m";cGRA="\e[37m"
	cBGRA="\e[90m";cBRED="\e[91m";cBGRE="\e[92m";cBYEL="\e[93m";cBBLU="\e[94m";cBMAG="\e[95m";cBCYA="\e[96m";cBWHT="\e[97m"
	aBOLD="\e[1m";aDIM="\e[2m";aUNDER="\e[4m";aBLINK="\e[5m";aREVERSE="\e[7m"
	cRED_="\e[41m";cGRE_="\e[42m"

}
Chk_Entware() {
		# ARGS [wait attempts] [specific_entware_utility]
		READY="1"					# Assume Entware Utilities are NOT available
		ENTWARE_UTILITY=""			# Specific Entware utility to search for
		MAX_TRIES="30"

		if [ -n "$2" ] && [ "$2" -eq "$2" ] 2>/dev/null; then
			MAX_TRIES="$2"
		elif [ -z "$2" ] && [ "$1" -eq "$1" ] 2>/dev/null; then
			MAX_TRIES="$1"
		fi

		if [ -n "$1" ] && ! [ "$1" -eq "$1" ] 2>/dev/null; then
			ENTWARE_UTILITY="$1"
		fi

		# Wait up to (default) 30 seconds to see if Entware utilities available.....
		TRIES="0"

		while [ "$TRIES" -lt "$MAX_TRIES" ]; do
			if [ -f "/opt/bin/opkg" ]; then
				if [ -n "$ENTWARE_UTILITY" ]; then            # Specific Entware utility installed?
					if [ -n "$(opkg list-installed "$ENTWARE_UTILITY")" ]; then
						READY="0"                                 # Specific Entware utility found
					else
						# Not all Entware utilities exists as a stand-alone package e.g. 'find' is in package 'findutils'
						if [ -d /opt ] && [ -n "$(find /opt/ -name "$ENTWARE_UTILITY")" ]; then
							READY="0"                               # Specific Entware utility found
						fi
					fi
				else
					READY="0"                                     # Entware utilities ready
				fi
				break
			fi
			sleep 1
			logger -st "($(basename "$0"))" "$$ Entware $ENTWARE_UTILITY not available - wait time $((MAX_TRIES - TRIES-1)) secs left"
			TRIES=$((TRIES + 1))
		done
		return "$READY"
}
Check_Lock() {
		if [ -f "/tmp/unbound.lock" ] && [ -d "/proc/$(sed -n '2p' /tmp/unbound.lock)" ] && [ "$(sed -n '2p' /tmp/unbound.lock)" != "$$" ]; then
			if [ "$(($(date +%s)-$(sed -n '3p' /tmp/unbound.lock)))" -gt "1800" ]; then
				Kill_Lock
			else
				logger -st unbound "[*] Lock File Detected ($(sed -n '1p' /tmp/unbound.lock)) (pid=$(sed -n '2p' /tmp/unbound.lock)) - Exiting (cpid=$$)"
				echo; exit 1
			fi
		fi
		if [ -n "$1" ]; then
			echo "$1" > /tmp/unbound.lock
		else
			echo "menu" > /tmp/unbound.lock
		fi
		echo "$$" >> /tmp/unbound.lock
		date +%s >> /tmp/unbound.lock
}
Kill_Lock() {
		if [ -f "/tmp/unbound.lock" ] && [ -d "/proc/$(sed -n '2p' /tmp/unbound.lock)" ]; then
			logger -st unbound "[*] Killing Locked Processes ($(sed -n '1p' /tmp/unbound.lock)) (pid=$(sed -n '2p' /tmp/unbound.lock))"
			logger -st unbound "[*] $(ps | awk -v pid="$(sed -n '2p' /tmp/unbound.lock)" '$1 == pid')"
			kill "$(sed -n '2p' /tmp/unbound.lock)"
			rm -rf /tmp/unbound.lock
			echo
		fi
}
welcome_message() {
		while true; do
			printf '\n+======================================================================+\n'
			printf '|  Welcome to the %bunbound-Installer-Asuswrt-Merlin%b installation script |\n' "$cBGRE" "$cRESET"
			printf '|  Version %s by Martineau                                           |\n' "$VERSION"
			printf '|                                                                      |\n'
			printf '| Requirements: USB drive with Entware installed                       |\n'
			printf '|                                                                      |\n'
			printf '| The install script will:                                             |\n'
			printf '|   1. Install the unbound Entware package                             |\n'
			printf '|   2. Override how the firmware manages DNS                           |\n'
			printf '|   3. Optionally Integrate with Stubby                                |\n'
			printf '|   4. Optionally Install Ad and Tracker Blocking                      |\n'
			printf '|                                                                      |\n'
			printf '| You can also use this script to uninstall unbound to back out the    |\n'
			printf '| changes made during the installation. See the project repository at  |\n'
			printf '| %bhttps://github.com/rgnldo/Unbound-Asuswrt-Merlin%b                     |\n' "$cBGRE" "$cRESET"
			printf '| for helpful tips.                                                    |\n'
			printf '+======================================================================+\n\n'
			if [ "$1" = "uninstall" ]; then
				menu1="2"
			else
				localmd5="$(md5sum "$0" | awk '{print $1}')"
				remotemd5="$(curl -fsL --retry 3 "${GITHUB_DIR}/unbound_installer_v1.0beta.sh" | md5sum | awk '{print $1}')"

				REMOTE_VERSION_NUMDOT="$(curl -fsLN --retry 3 "${GITHUB_DIR}/unbound_installer_v1.0beta.sh" | grep -E "^VERSION" | tr -d '"' | sed 's/VERSION\=//')"	# v1.05

				LOCAL_VERSION_NUM=$(echo $VERSION | sed 's/[^0-9]*//g')				# v1.04
				REMOTE_VERSION_NUM=$(echo $REMOTE_VERSION_NUMDOT | sed 's/[^0-9]*//g')	# v1.04

				[ -n $(pidof unbound) ] && UNBOUND_STATUS="ACTIVE (PID="$(pidof unbound)") " || UNBOUND_STATUS=		# v1.06

				if [ -f /opt/etc/unbound/unbound.conf ]; then					# v1.06
					printf '%b1%b = Update %sunbound Configuration\n' "${cBYEL}" "${cRESET}" "$UNBOUND_STATUS"
				else
					printf '%b1%b = Begin unbound Installation Process\n' "${cBYEL}" "${cRESET}"
				fi
				printf '%b2%b = Remove Existing unbound Installation\n' "${cBYEL}" "${cRESET}"

				if [ "$localmd5" != "$remotemd5" ]; then
					if [ $REMOTE_VERSION_NUM -gt $LOCAL_VERSION_NUM ];then				# v1.04
						printf '%b3%b = Update unbound_installer.sh %s -> %s\n' "${cBYEL}" "${cRESET}" "v$VERSION" "v$REMOTE_VERSION_NUMDOT"	# v1.04
					else
						printf '%b3 = Downgrade unbound_installer.sh %s <- %s\n' "${cBRED}" "v$VERSION" "v$REMOTE_VERSION_NUMDOT"	# v1.04
					fi
				fi
				[ -n "$(pidof unbound)" ] && printf '\n%bs%b = Display unbound statistics\n' "${cBYEL}" "${cRESET}"

				printf '\n%be%b = Exit Script\n' "${cBYEL}" "${cRESET}"
				printf '\n%bOption ==>%b ' "${cBYEL}" "${cRESET}"
				read -r "menu1"
			fi
			case "$menu1" in
				1)
					install_unbound "$@"
					break
				;;
				2)
					validate_removal
					break
				;;
				3)
					update_installer
					break
				;;
			    s)
					unbound-control stats_noreset
					break
				;;
				e)
					exit_message
					break
				;;
				*)
					printf '%bInvalid Option%b %s%b Please enter a valid option\n' "$cBRED" "$cBGRE" "$menu1" "$cRESET"
				;;
			esac
		done
}
exit_message() {
		rm -rf /tmp/unbound.lock
		echo -e $cRESET
		exit 0
}
validate_removal () {
		while true; do
			printf '\n%bIMPORTANT: The router will need to reboot in order to complete the removal of unbound%b\n\n' "${cBRED}" "${cRESET}"
			printf '%by%b = Are you sure you want to uninstall unbound?\n' "${cBYEL}" "${cRESET}"
			printf '%bn%b = Cancel\n' "${cBYEL}" "${cRESET}"
			printf '%be%b = Exit Script\n' "${cBYEL}" "${cRESET}"
			printf '\n%bOption ==>%b ' "${cBYEL}" "${cRESET}"
			read -r "menu3"
			case "$menu3" in
				y)
					remove_existing_installation
					break
				;;
				n)
					welcome_message
					break
				;;
				e)
					exit_message
					break
				;;
				*)
					printf '%bInvalid Option%b %s%b Please enter a valid option\n' "$cBRED" "$cBGRE" "$menu3" "$cRESET"
				;;
			esac
		done
}
is_dir_empty() {
		DIR="$1"
		cd "$DIR" || return 1
		set -- .[!.]* ; test -f "$1" && return 1
		set -- ..?* ; test -f "$1" && return 1
		set -- * ; test -f "$1" && return 1
		return 0
}
check_dnsmasq_parms() {
		if [ -s "/etc/dnsmasq.conf" ]; then  # dnsmasq.conf file exists
			for DNSMASQ_PARM in "server=127.0.0.1#53535" "domain-needed" "no-negcache" "min-port=4096" "cache-size=1500"; do		# v1.06
				if grep -q "$DNSMASQ_PARM" "/etc/dnsmasq.conf"; then  # see if line exists
					printf 'Required dnsmasq parm %b%s%b found in /etc/dnsmasq.conf\n' "${cBGRE}" "$DNSMASQ_PARM" "${cRESET}"
					continue #line found in dnsmasq.conf, no update required to /jffs/configs/dnsmasq.conf.add
				fi
				if [ -s "/jffs/configs/dnsmasq.conf.add" ]; then
					if grep -q "$DNSMASQ_PARM" "/jffs/configs/dnsmasq.conf.add"; then  # see if line exists
						#printf '%b%s%b found in /jffs/configs/dnsmasq.conf.add\n' "${cBGRE}" "$DNSMASQ_PARM" "${cRESET}"
						:
					else
						printf 'Adding %b%s%b to /jffs/configs/dnsmasq.conf.add\n' "${cBGRE}" "$DNSMASQ_PARM" "${cRESET}"
						printf '%s\n' "$DNSMASQ_PARM" >> /jffs/configs/dnsmasq.conf.add
					fi
				else
					printf 'Adding %b%s%b to /jffs/configs/dnsmasq.conf.add\n' "${cBGRE}" "$DNSMASQ_PARM" "${cRESET}"
					printf '%s\n' "$DNSMASQ_PARM" > /jffs/configs/dnsmasq.conf.add
				fi
			done
		else
			echo -e $cBRED"\n\n\t***ERROR '/etc/dnsmasq.conf' file not found?. dnsmasq appears to not be configured on your router. Check router configuration"$cRESET
			exit_message
			exit 1
		fi
}
check_dnsmasq_postconf() {
		if [ -s "/jffs/scripts/dnsmasq.postconf" ]; then  # dnsmasq.postconf file exists		# v1.05
			if [ "$1" != "del" ];then
				[ -z "$(grep -E "^pc_delete.*servers\-file" /jffs/scripts/dnsmasq.postconf)" ] && echo -e "pc_delete \"servers-file\" \$CONFIG\t\t\t# unbound_installer" >> /jffs/scripts/dnsmasq.postconf
				[ -z "$(grep -E "^pc_delete.*no\-negcache" /jffs/scripts/dnsmasq.postconf)" ] && echo -e "pc_delete \"no-negcache\" \$CONFIG\t\t\t# unbound_installer" >> /jffs/scripts/dnsmasq.postconf
				[ -z "$(grep -E "^pc_delete.*domain\-needed" /jffs/scripts/dnsmasq.postconf)" ] && echo -e "pc_delete \"domain-needed\" \$CONFIG\t\t\t# unbound_installer" >> /jffs/scripts/dnsmasq.postconf
				[ -z "$(grep -E "^pc_delete.*bogus-priv" /jffs/scripts/dnsmasq.postconf)" ] && echo -e "pc_delete \"bogus-priv\" \$CONFIG\t\t\t# unbound_installer" >> /jffs/scripts/dnsmasq.postconf
				echo -e "pc_replace \"cache-size=1500\" \"cache-size=0\" \$CONFIG\t\t\t# unbound_installer" >> /jffs/scripts/dnsmasq.postconf
			else
				sed -i '/#.*unbound_installer/d' /jffs/scripts/dnsmasq.postconf
			fi
		else
			{ echo "#!/bin/sh
CONFIG=\$1
source /usr/sbin/helper.sh
pc_delete \"servers-file\" \$CONFIG
pc_delete \"no-negcache\" \$CONFIG
pc_delete \"domain-needed\" \$CONFIG
pc_delete \"bogus-priv\" \$CONFIG
pc_replace \"cache-size=1500\" \"cache-size=0\" \$CONFIG
pc_append \"server=127.0.0.1#53535\" \$CONFIG"; }			> /jffs/scripts/dnsmasq.postconf
			chmod +x /jffs/scripts/dnsmasq.postconf			# v1.06
		fi
}
create_required_directories() {
		for DIR in  "/opt/etc/unbound" "/opt/var/lib/unbound" "/opt/var/log"; do
			if [ ! -d "$DIR" ]; then
				if mkdir -p "$DIR" >/dev/null 2>&1; then
					printf "Created project directory %b%s%b\\n" "${cBGRE}" "${DIR}" "${cRESET}"
					[ "$DIR" == "/opt/etc/unbound" ] && chown nobody /opt/etc/unbound
				else
					printf "%b***ERROR creating directory %b%s%b. Exiting $(basename "$0")\\n" "$cBRED" "${cBGRE}" "${DIR}" "${cRESET}"
					exit 1
				fi
			fi
		done
}
make_backup() {
		DIR="$1"
		FILE="$2"
		TIMESTAMP="$(date +%Y-%m-%d_%H-%M-%S)"
		BACKUP_FILE_NAME="${FILE}.${TIMESTAMP}"
		if [ -f "$DIR/$FILE" ]; then
			if ! mv "$DIR/$FILE" "$DIR/$BACKUP_FILE_NAME" >/dev/null 2>&1; then
				printf 'Error backing up existing %b%s%b to %b%s%b\n' "$cBGRE" "$FILE" "$cRESET" "$cBGRE" "$BACKUP_FILE_NAME" "$cRESET"
				printf 'Exiting %s\n' "$(basename "$0")"
				exit 1
			else
				printf 'Existing %b%s%b found\n' "$cBGRE" "$FILE" "$cRESET"
				printf '%b%s%b backed up to %b%s%b\n' "$cBGRE" "$FILE" "$cRESET" "$cBGRE" "$BACKUP_FILE_NAME" "$cRESET"
			fi
		fi
}
download_file() {
		DIR="$1"
		FILE="$2"
		STATUS="$(curl --retry 3 -sL -w '%{http_code}' "$GITHUB_DIR/$FILE" -o "$DIR/$FILE")"
		if [ "$STATUS" -eq "200" ]; then
			printf '\t%b%s%b downloaded successfully\n' "$cBGRE" "$FILE" "$cRESET"
		else
			printf '\n%b%s%b download failed with curl error %s\n\n' "\n\t\a$cBRED" "$FILE" "$cBRED" "$STATUS"
			printf 'Rerun %binstall_unbound.sh%b and select the %bRemove Existing unbound Installation%b option\n' "$cBGRE" "$cRESET" "$cBGRE" "$cRESET"
			exit 1
		fi
}
S61unbound_update() {

	echo -e $cBCYA"Updating S61unbound"$cBGRA

	if [ -d "/opt/etc/init.d" ]; then
		/opt/bin/find /opt/etc/init.d -type f -name S61unbound\* | while IFS= read -r "line"; do
			rm "$line"
		done
	fi
	#download_file /opt/etc/init.d S61unbound

	{
	echo "#!/bin/sh
if [ \"\$1\" = \"start\" ] || [ \"\$1\" = \"restart\" ]; then
	   # Wait for NTP before starting
	   logger -st \"S61unbound\" \"Waiting for NTP to sync before starting...\"
	   ntptimer=0
	   while [ \"\$(nvram get ntp_ready)\" = \"0\" ] && [ \"\$ntptimer\" -lt \"300\" ]; do
			   ntptimer=\$((ntptimer+1))
			   sleep 1
	   done

	   if [ \"\$ntptimer\" -ge \"300\" ]; then
			   logger -st \"S61unbound\" \"NTP failed to sync after 5 minutes - please check immediately!\"
			   echo \"\"
			   exit 1
	   fi
fi

export TZ=\$(cat /etc/TZ)
ENABLED=yes
PROCS=unbound
ARGS=\"-c /opt/etc/unbound/unbound.conf\"
PREARGS=\"nohup\"
PRECMD=\"\"
POSTCMD=\"service restart_dnsmasq\"
DESC=\$PROCS
PATH=/opt/sbin:/opt/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

. /opt/etc/init.d/rc.func"; } > /opt/etc/init.d/S61unbound

	chmod 755 /opt/etc/init.d/S61unbound >/dev/null 2>&1
}
S02haveged_update() {

	echo -e $cBCYA"Updating S02haveged"$cGRA

	if [ -d "/opt/etc/init.d" ]; then
		/opt/bin/find /opt/etc/init.d -type f -name S02haveged* | while IFS= read -r "line"; do
			rm "$line"
		done
	fi
	#download_file /opt/etc/init.d S02haveged

	{
	echo "#!/bin/sh
if [ \"\$1\" = \"start\" ] || [ \"\$1\" = \"restart\" ]; then
        # Wait for NTP before starting
        logger -st \"S02haveged\" \"Waiting for NTP to sync before starting...\"
        ntptimer=0
        while [ \"\$(nvram get ntp_ready)\" = \"0\" ] && [ \"\$ntptimer\" -lt \"300\" ]; do
                ntptimer=\$((ntptimer+1))
                sleep 1
        done

        if [ \"\$ntptimer\" -ge \"300\" ]; then
                logger -st \"S02haveged" "NTP failed to sync after 5 minutes - please check immediately!\"
                echo \"\"
                exit 1
        fi
fi
export TZ=\$(cat /etc/TZ)
ENABLED=yes
PROCS=haveged
ARGS=\"-w 1024 -d 32 -i 32 -v 1\"
PREARGS=\"\"
DESC=\$PROCS
PATH=/opt/sbin:/opt/bin:/opt/usr/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

. /opt/etc/init.d/rc.func"; } > /opt/etc/init.d/S02haveged

	chmod 755 /opt/etc/init.d/S02haveged >/dev/null 2>&1
}
Redirect_outbound_DNS_requests() {

	iptables -t nat -D PREROUTING -d "$(nvram get lan_ipaddr)" -p tcp --dport 53 -j REDIRECT --to-port 53535 2>/dev/null
	iptables -t nat -D PREROUTING -d "$(nvram get lan_ipaddr)" -p udp --dport 53 -j REDIRECT --to-port 53535 2>/dev/null

	if [ "$1" != "del" ] ;then
		logger -t unbound "[*] Updating nat firewall rules to redirect ALL DNS requests"
		echo -e $cBCYA"\nUpdating nat firewall rules to redirect ALL DNS requests"$cRESET
		iptables -t nat -A PREROUTING -d "$(nvram get lan_ipaddr)" -p tcp --dport 53 -j REDIRECT --to-port 53535
		iptables -t nat -A PREROUTING -d "$(nvram get lan_ipaddr)" -p udp --dport 53 -j REDIRECT --to-port 53535

		if [ -z "$(grep -E "# unbound.*" /jffs/scripts/firewall-start | grep -v "^#")" ]; then
			echo -e $cBCYA"Updating 'firewall-start' to redirect ALL DNS requests to unbound"$cRESET
			[ ! -f /jffs/scripts/firewall-start ] && { echo "#!/bin/sh" > /jffs/scripts/firewall-start; chmod +x /jffs/scripts/firewall-start; }
			EXEC="sh /jffs/scripts/unbound_installer.sh firewall # unbound Firewall Addition"
			echo -e "$EXEC" >> /jffs/scripts/firewall-start
		else
			echo -e $cBGRE"'firewall-start' already contains unbound rule request to redirect ALL DNS requests"$cRESET
		fi
	else
		logger -t unbound "[*] Deleted unbound firewall rules."
		echo -e $cBGRE"Deleted unbound firewall rules from 'firewall-start'"$cRESET
		sed -i '/# unbound Firewall Addition/d' /jffs/scripts/firewall-start
	fi
}
Ad_Tracker_blocking() {

	echo -e $cBCYA"Installing Ads and Tracker Blocking....."$cRESET		# v1.06

	download_file /opt/tmp unbound_adblock.tar.bz2
	echo -e $cBCYA"Unzipping 'unbound_adblock.tar.bz2'....."$cBGRA
	tar -jxvf /opt/tmp/unbound_adblock.tar.bz2 -C /jffs

	chmod +x /jffs/adblock/gen_adblock.sh
	echo -e $cBCYA"Executing '/jffs/adblock/gen_adblock.sh'....."$cBGRA
	sh /jffs/adblock/gen_adblock.sh				# Apparently requests '/opt/etc/init.d/S61unbound start'

	if [ -z "$(grep "/jffs/adblock/adservers" /opt/etc/unbound/unbound.conf)" ];then
		echo -e $cBCYA"Customising '/opt/etc/unbound/unbound.conf'"$cRESET
		# Tricky Hack...'include:' may only appear after 'server:' ??? of which there are several 'server:' directives :-(
		sed -i '1,/server:/s/server:/server:\ninclude: \/jffs\/adblock\/adservers/' /opt/etc/unbound/unbound.conf
	fi
	echo -e $cRESET
}
Stubby_Integration() {

	echo -e $cBCYA"Integrating Stubby with unbound....."$cBGRA
	opkg install stubby ca-bundle

	download_file /opt/etc/stubby/ stubby.yml
	download_file /opt/etc/init.d S62stubby
	chmod +x /opt/etc/init.d/S62stubby

	echo -e $cBCYA"Adding Stubby 'forward-zone:' in '/opt/etc/unbound/unbound.conf'"$cRESET

	if [ -z "$(grep -F "forward-addr: 127.0.0.1@5453" /opt/etc/unbound/unbound.conf)" ];then
		# Tricky Hack...as there are TWO uncommented '# forward\-zone:' lines!!!!!!
		sed -i '1,/# forward\-zone:/s/# forward\-zone:.*/forward\-zone:/' /opt/etc/unbound/unbound.conf		# v1.04
		sed -i '/forward\-no\-cache:.*no/aname: \"\.\" \
forward-addr: 127\.0\.0\.1@5453 \
forward-addr: 0::1@5453 \
forward-first: yes' /opt/etc/unbound/unbound.conf
	fi
}
Customise_config() {

	 echo -e $cBCYA"Customising '/opt/etc/unbound/unbound.conf'"$cRESET

	 sed -i 's/# port: 53/port: 53535/' /opt/etc/unbound/unbound.conf

	 sed -i 's/# do\-ip4:.*/do\-ip4: yes/' /opt/etc/unbound/unbound.conf
	 sed -i 's/# do\-ip6:.*/do\-ip6: yes/' /opt/etc/unbound/unbound.conf
	 sed -i 's/# do\-udp:.*/do\-udp: yes/' /opt/etc/unbound/unbound.conf
	 sed -i 's/# do\-tcp:.*/do\-tcp: yes/' /opt/etc/unbound/unbound.conf

	 sed -i 's/#num\-threads:.*/num\-threads: 1/' /opt/etc/unbound/unbound.conf
	 sed -i 's/msg\-cache\-slabs:.*/msg\-cache\-slabs: 2/' /opt/etc/unbound/unbound.conf
	 sed -i 's/rrset\-cache\-slabs:.*/rrset\-cache\-slabs: 2/' /opt/etc/unbound/unbound.conf
	 sed -i 's/infra\-cache\-slabs:.*/infra\-cache\-slabs: 2/' /opt/etc/unbound/unbound.conf
	 sed -i 's/key\-cache\-slabs:.*/key\-cache\-slabs: 2/' /opt/etc/unbound/unbound.conf
	 sed -i 's/outgoing\-num-tcp:.*/outgoing\-num-tcp: 1000/' /opt/etc/unbound/unbound.conf
	 sed -i 's/incoming\-num\-tcp:.*/incoming\-num\-tcp: 1000/' /opt/etc/unbound/unbound.conf
	 sed -i 's/# udp\-upstream\-without\-downstream:.*/udp\-upstream\-without\-downstream: yes/' /opt/etc/unbound/unbound.conf

	 sed -i 's/# key\-cache\-size:.*/key\-cache\-size: 32m/' /opt/etc/unbound/unbound.conf

	 sed -i 's/prefetch:.*/prefetch: yes/' /opt/etc/unbound/unbound.conf
	 sed -i 's/prefetch\-key:.*/prefetch\-key: yes/' /opt/etc/unbound/unbound.conf
	 sed -i 's/minimal\-responses:.*/minimal\-responses: yes/' /opt/etc/unbound/unbound.conf

	 sed -i 's/#module\-config:.*/module\-config: \"validator iterator\"/' /opt/etc/unbound/unbound.conf
	 sed -i 's~#auto\-trust\-anchor\-file:.*~auto\-trust\-anchor\-file: \"/opt/var/lib/unbound/root.key\"~' /opt/etc/unbound/unbound.conf

	 sed -i 's/# hide\-identity:.*/hide\-identity: yes/' /opt/etc/unbound/unbound.conf
	 sed -i 's/# hide\-version:.*/hide\-version: yes/' /opt/etc/unbound/unbound.conf

	 sed -i 's/# do\-not\-query\-localhost:.*/do\-not\-query\-localhost: yes/' /opt/etc/unbound/unbound.conf
	 sed -i 's/# qname\-minimisation:.*/qname\-minimisation: yes/' /opt/etc/unbound/unbound.conf
	 sed -i 's/# harden\-glue:.*/harden\-glue: yes/' /opt/etc/unbound/unbound.conf

	 echo -e $cBCYA"Retrieving '/opt/var/lib/unbound/root-hints'"$cBGRA
	 curl -o /opt/var/lib/unbound/root.hints https://www.internic.net/domain/named.cache
	 [ $? -eq 0 ] && sed -i 's~# root\-hints:.*~root\-hints: \"/opt/var/lib/unbound/root\.hints\"~' /opt/etc/unbound/unbound.conf
	 echo -en $cRESET
}
Enable_unbound_statistics() {

	# unbound-control-setup uses 'setup in directory /opt/var/lib/unbound' ???
	# generating unbound_server.key
	# Generating RSA private key, 3072 bit long modulus
	# ....................................++++
	# .......................................................................................................................................................................++++
	# e is 65537 (0x10001)
	# generating unbound_control.key-file
	echo -e $cBCYA"Initialising 'unbound-control-setup'"$cBGRA
	unbound-control-setup

		echo -e $cBCYA"Enabling unbound 'remote-control:' in '/opt/etc/unbound/unbound.conf'"$cRESET
	if [ -z "$(grep -F "control-port: 953" /opt/etc/unbound/unbound.conf)" ];then		# v1.06
		sed -ibak '/remote-control:/acontrol-enable: yes \
control-interface: 127\.0\.0\.1 \
server-key-file: "/opt/var/lib/unbound/unbound_server\.key" \
server-cert-file: "/opt/var/lib/unbound/unbound_server\.pem" \
control-key-file: "/opt/var/lib/unbound/unbound_control\.key" \
control-cert-file: "/opt/var/lib/unbound/unbound_control\.pem" \
control-port: 953' /opt/etc/unbound/unbound.conf
		echo -e $cBMAG"Use 'unbound-control stats_noreset' to monitor unbound performance"$cRESET
	fi
}
Check_SWAP() {
	local SWAPSIZE=$(grep "SwapTotal" /proc/meminfo | awk '{print $2}')
	[ $SWAPSIZE -gt 0 ] && { echo $SWAPSIZE; return 0;} || { echo $SWAPSIZE; return 1; }
}
update_installer() {
	if [ "$localmd5" != "$remotemd5" ]; then
		download_file /jffs/scripts unbound_installer_v1.0beta.sh
		#***********************************Temporary hack*************************************************
		echo -e $cBGRE"\t$FILE --> '/jffs/scripts/unbound_installer.sh'"$cRESET
		chmod 755 /jffs/scripts/$FILE;mv /jffs/scripts/$FILE /jffs/scripts/unbound_installer_v1.0beta.sh;dos2unix /jffs/scripts/unbound_installer.sh
		#**************************************************************************************************
		printf '\n\n%bUpdate Complete! %s\n' "$cBGRE" "$remotemd5"
	else
		printf '\n%bunbound_installer.sh is already the latest version. %s\n' "$cBMAG" "$localmd5"
	fi
	echo -e $cRESET
	exit_message
}
remove_existing_installation() {

		echo -e $cBCYA"\nUninstalling unbound"$cRESET

		# Remove firewall rules
		sed -i '/unbound_installer.sh/d' "/jffs/scripts/firewall-start" >/dev/null
		Redirect_outbound_DNS_requests "del"

		# Kill unbound process
		echo -en $cBRED
		pidof unbound | while read -r "spid" && [ -n "$spid" ]; do
			kill "$spid"
		done

		echo -en $cRESET

		# Remove the unbound package
		Chk_Entware unbound
		if [ "$READY" -eq "0" ]; then
			echo -e $cBCYA"Existing unbound package found. Removing unbound"$cBGRA
			if opkg remove unbound-control-setup unbound-control unbound-anchor unbound-daemon; then echo -e $cBGRE"unbound successfully removed"; else echo -e $cBRED"\a\n\t***Error occurred when removing unbound"$cRESET; fi
			#if opkg remove haveged; then echo "haveged successfully removed"; else echo "Error occurred when removing haveged"; fi
		else
			echo -e $cRED"Unable to remove unbound - 'unbound' not installed?"$cRESET
		fi

		# Remove entries from /jffs/configs/dnsmasq.conf.add
		if [ -s "/jffs/configs/dnsmasq.conf.add" ]; then  # file exists
			for DNSMASQ_PARM in "^server=127\.0\.0\.1*#53535"; do
				if [ -n "$(grep -oE "$DNSMASQ_PARM" /jffs/configs/dnsmasq.conf.add)" ]; then  # see if line exists
					sed -i "\\~$DNSMASQ_PARM~d" "/jffs/configs/dnsmasq.conf.add"
				fi
			done
		fi

		service restart_dnsmasq >/dev/null 2>&1			# Just in case reboot is skipped!

		# Purge unbound directories
		for DIR in  "/opt/etc/unbound" "/opt/var/lib/unbound"; do
			if [ -d "$DIR" ]; then
				if ! rm "$DIR"/* >/dev/null 2>&1; then
					printf '\n%bNo files found to remove in %b%s%b\n' "${cRESET}$cRED" "$cBGRE" "$DIR" "$cRESET"
				fi
				if ! rmdir "$DIR" >/dev/null 2>&1; then
					printf '\n%b***ERROR trying to remove %b%s%b\n' "${cRESET}$cRED" "$cBGRE" "$DIR" "$cRESET"
				else
					printf '\n%b%s%b folder and all files removed\n' "$cBGRE"  "$DIR" "$cRESET"
				fi
			else
				printf '\n%b%s%b folder does not exist. No directory to remove%b\n' "$cGRE" "$DIR" "$cRED" "$cRESET"
			fi
		done

		# Remove /opt/var/log/unbound.log file
		if [ -f "/opt/var/log/unbound.log" ]; then  # file exists
			rm "/opt/var/log/unbound.log"
		fi

		# remove file /opt/etc/init.d/S61unbound
		if [ -d "/opt/etc/init.d" ]; then
			/opt/bin/find /opt/etc/init.d -type f -name S61unbound\* -delete
		fi

		# remove /jffs/scripts/nat-start
		if grep -qF "unbound Installer" /jffs/scripts/nat-start; then
			sed -i '\~ unbound Installer~d' /jffs/scripts/nat-start
		fi

		check_dnsmasq_postconf "del"

		# Remove /opt symlink
		rm -rf "/opt/bin/install_unbound" "/jffs/scripts/install_unbound.sh"

		# Reboot router to complete uninstall of unbound
		echo -e $cBGRE"\n\n\tUninstall of unbound completed."$cRESET

		echo -e "\nThe router will now$cBRED REBOOT$cRESET to finalize the removal of unbound"
		echo -e "After the$cBRED REBOOT$cRESET, review the DNS settings on the WAN GUI and adjust if necessary"
		echo
		echo -e "Press$cBRED Y$cRESET to$cBRED REBOOT $cRESET or press$cBGRE ENTER to ABORT"
		read -r "CONFIRM_REBOOT"
		[ "$CONFIRM_REBOOT" == "Y" ] && { echo -e $cBRED"\a\n\n\tREBOOTing....."; service start_reboot; } || echo -e $cBGRE"\tReboot ABORTED\n"$cRESET
}
install_unbound() {

		echo -en $cBCYA"\nConfiguring unbound"$cRESET

		if [ -d "/jffs/dnscrypt" ] || [ -f "/opt/sbin/dnscrypt-proxy" ]; then
			echo "Warning! DNSCrypt installation detected"
			printf 'Please remove this script to continue installing unbound\n\n'
			exit 1
		fi
		echo
		if Chk_Entware; then
			if opkg update >/dev/null 2>&1; then
				echo -e $cBGRE"Entware package list successfully updated"$cBGRA
			else
				echo -e $cBRED"***ERROR occurred updating Entware package list"$cRESET
				exit 1
			fi
		else
			echo -e $cBRED"You must first install Entware before proceeding see 'amtm'"$cRESET
			printf 'Exiting %s\n' "$(basename "$0")"
			exit 1
		fi

		if opkg install unbound-daemon unbound-control unbound-control-setup unbound-anchor --force-downgrade; then
			echo -e $cBGRE"unbound Entware packages 'unbound-daemon unbound-control unbound-control-setup unbound-anchor' successfully installed"$cBGRA
		else
			echo -e $cBRED"\a\n\n\t***ERROR occurred installing unbound\n"$cRESET
			exit 1
		fi
		if opkg install haveged; then
			echo -e $cBGRE"Haveged successfully updated"$cRESET
		else
			echo -e $cBRED"***ERROR occurred updating Haveged"$cRESET
			exit 1
		fi

		S02haveged_update
		# if ! grep -qF "export TZ=\$(cat /etc/TZ)" /opt/etc/init.d/S02haveged; then
			# sed -i "3i export TZ=\$(cat /etc/TZ)" /opt/etc/init.d/S02haveged
		# fi
		/opt/etc/init.d/S02haveged restart

		check_dnsmasq_parms
		check_dnsmasq_postconf
		create_required_directories
		/opt/sbin/unbound-anchor -a /opt/var/lib/unbound/root.key

		#update_wan_and_resolv_settings

		if [ -d "/opt/bin" ] && [ ! -L "/opt/bin/unbound_installer" ]; then
			ln -s /jffs/scripts/unbound_installer.sh /opt/bin/unbound_installer	# v1.04
		fi

		echo -e $cBCYA"Linking '/opt/etc/unbound/unbound.conf' --> '/opt/var/lib/unbound/unbound.conf'"$cRESET
		ln -s /opt/etc/unbound/unbound.conf /opt/var/lib/unbound/unbound.conf 2>/dev/null	# Hack to retain '/opt/etc/unbound' for configs

		Enable_unbound_statistics

		S61unbound_update
		Customise_config

		echo -e "\nDo you want to integrate Stubby with unbound?\n\n\tReply$cBRED 'y' or press$cBGRE ENTER $cRESET to skip"
		read -r "ANS"
		[ "$ANS" == "y"  ] && Stubby_Integration

		echo -e "\nDo you want to install Ad and Tracker blocking?\n\n\tReply$cBRED 'y' or press$cBGRE ENTER $cRESET to skip"
		read -r "ANS"
		[ "$ANS" == "y"  ] && Ad_Tracker_blocking		# v1.06 (Apparently requests '/opt/etc/init.d/S61unbound start')

		# ....but just in case ;-)
		[ -z "$(pidof unbound)" ] && /opt/etc/init.d/S61unbound start || /opt/etc/init.d/S61unbound restart	# Will also restart dnsmasq

		# unbound apparently has a habit of taking its time to process its 'unbound.conf' and may terminate due to invalid directives
		echo -e $cBCYA"\nPaused for 1 sec to allow unbound to validate 'unbound.conf'"			# v1.06
		sleep 1																					# v1.06

		[ -n "$(pidof unbound)" ] && Redirect_outbound_DNS_requests

		if pidof unbound >/dev/null 2>&1; then
			echo -e $cBGRE"\n\tInstallation of unbound completed\n"		# v1.04
		else
			echo -e $cBRED"\a\n\t***ERROR Unsuccessful installation of unbound detected\n"		# v1.04
			echo -en ${cRESET}$cRED_
			unbound -c /opt/etc/unbound/unbound.conf				# v1.06
			echo -e $cRESET"\n"
			printf '\tRerun %bunbound_installer.sh%b and select the %bRemove%b option to backout changes\n\n' "$cBGRE" "$cRESET" "$cBGRE" "$cRESET"

		fi

		echo -e $cBCYA"Checking Router Configuration pre-reqs....."	# v1.04
		# Check Swap file
		[ $(Check_SWAP) -eq 0 ] && echo -e $cBRED"[✖]Warning SWAP file is not configured $cRESET - use amtm to create one!" || echo -e $cBGRE"[✔] Swapfile="$(grep "SwapTotal" /proc/meminfo | awk '{print $2" "$3}')$cRESET	# v1.04

		#	DNSFilter: ON - mode Router
		if [ $(nvram get dnsfilter_enable_x) -eq 0 ];then
			echo -e $cBRED"\a\[✖] ***ERROR DNS Filter is OFF! - $cRESET see http://$(nvram get lan_ipaddr)/DNSFilter.asp LAN->DNSFilter Enable DNS-based Filtering"
		else
			echo -e $cBGRE"[✔] DNS Filter=ON"
			#	DNSFilter: ON - Mode Router ?
			[ $(nvram get dnsfilter_mode) != "11" ] && echo -e $cBRED"\a[✖] ***ERROR DNS Filter is NOT = 'Router' $cRESET see http://$(nvram get lan_ipaddr)/DNSFilter.asp ->LAN->DNSFilter"$cRESET || echo -e $cBGRE"[✔] DNS Filter=ROUTER"
		fi

		#	Tools/Other WAN DNS local cache: NO # for the FW Merlin development team, it is desirable and safer by this mode.
		[ $(nvram get nvram get dns_local_cache) != "0" ] && echo -e $cBRED"\a[✖] ***ERROR WAN: Use local caching DNS server as system resolver=YES $cRESET see http://$(nvram get lan_ipaddr)/Tools_OtherSettings.asp ->Advanced Tweaks and Hacks"$cRESET || echo -e $cBGRE"[✔] WAN: Use local caching DNS server as system resolver=NO"

		#	Configure NTP server Merlin
		[ $(nvram get ntpd_enable) == "0" ] && echo -e $cBRED"\a[✖] ***ERROR Enable local NTP server=NO $cRESET see http://$(nvram get lan_ipaddr)/Advanced_System_Content.asp ->Basic Config"$cRESET || echo -e $cBGRE"[✔] Enable local NTP server=YES"

		exit_message
}
#=============================================Main=============================================================
# shellcheck disable=SC2068
Main() { true; } # Syntax that is Atom Shellchecker compatible!

clear
Check_Lock "$1"

[ "$1" == "firewall" ] && { Redirect_outbound_DNS_requests; exit 0; }		# Called from firewall-start?

ANSIColours

welcome_message "$@"

echo -e $cRESET

rm -rf /tmp/unbound.lock
