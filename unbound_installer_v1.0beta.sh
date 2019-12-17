#!/bin/sh
####################################################################################################
# Script: install_unbound.sh
# Original Author: Martineau
# Maintainer:
# Last Updated Date: 17-Dec-2019
#
# Description:
#  Install the unbound DNS over TLS resolver package from Entware on Asuswrt-Merlin firmware.
#  See https://github.com/rgnldo/Unbound-Asuswrt-Merlin for a description of system changes
#
# Acknowledgement:
#  Chk_Entware function provided by Martineau.
#  Test team: 
#  Contributors: Xentrk. Adamm & Jack Yaz both forked and updated the original installer to provide support
#                for HND routers. Adamm also implemented the performance improvements listed below,
#                and performs ongoing code maintainance.
#
#
####################################################################################################
export PATH=/sbin:/bin:/usr/sbin:/usr/bin$PATH
logger -t "($(basename "$0"))" "$$ Starting Script Execution ($(if [ -n "$1" ]; then echo "$1"; else echo "menu"; fi))"
VERSION="1.02"
GIT_REPO="unbound-Asuswrt-Merlin"
GITHUB_DIR="https://raw.githubusercontent.com/rgnldo/$GIT_REPO/master"


# Uncomment the line below for debugging
#set -x

COLOR_RED='\033[0;31m'
COLOR_WHITE='\033[0m'
COLOR_GREEN='\e[0;32m'

Check_Lock () {
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

Kill_Lock () {
		if [ -f "/tmp/unbound.lock" ] && [ -d "/proc/$(sed -n '2p' /tmp/unbound.lock)" ]; then
			logger -st unbound "[*] Killing Locked Processes ($(sed -n '1p' /tmp/unbound.lock)) (pid=$(sed -n '2p' /tmp/unbound.lock))"
			logger -st unbound "[*] $(ps | awk -v pid="$(sed -n '2p' /tmp/unbound.lock)" '$1 == pid')"
			kill "$(sed -n '2p' /tmp/unbound.lock)"
			rm -rf /tmp/unbound.lock
			echo
		fi
}

welcome_message () {
		while true; do
			printf '\n+======================================================================+\n'
			printf '|  Welcome to the %bunbound-Installer-Asuswrt-Merlin%b installation script |\n' "$COLOR_GREEN" "$COLOR_WHITE"
			printf '|  Version %s by Martineau                                           |\n' "$VERSION"
			printf '|                                                                      |\n'
			printf '| Requirements: USB drive with Entware installed                       |\n'
			printf '|                                                                      |\n'
			printf '| The install script will:                                             |\n'
			printf '|   1. Install the unbound Entware package                             |\n'
			printf '|   2. Override how the firmware manages DNS                           |\n'
			printf '|   3. Disable the firmware DNSSEC setting                             |\n'
			printf '|                                                                      |\n'
			printf '| You can also use this script to uninstall unbound to back out the    |\n'
			printf '| changes made during the installation. See the project repository at  |\n'
			printf '| %bhttps://github.com/rgnldo/Unbound-Asuswrt-Merlin%b                     |\n' "$COLOR_GREEN" "$COLOR_WHITE"
			printf '| for helpful tips.                                                    |\n'
			printf '+======================================================================+\n\n'
			if [ "$1" = "uninstall" ]; then
				menu1="2"
			else
				localmd5="$(md5sum "$0" | awk '{print $1}')"
				remotemd5="$(curl -fsL --retry 3 "${GITHUB_DIR}/unbound_installer.sh" | md5sum | awk '{print $1}')"
				if pidof unbound >/dev/null 2>&1; then
					printf '%b1%b = Update unbound Configuration\n' "${COLOR_GREEN}" "${COLOR_WHITE}"
				else
					printf '%b1%b = Begin unbound Installation Process\n' "${COLOR_GREEN}" "${COLOR_WHITE}"
				fi
				printf '%b2%b = Remove Existing unbound Installation\n' "${COLOR_GREEN}" "${COLOR_WHITE}"
				if [ "$localmd5" != "$remotemd5" ]; then
					printf '%b3%b = Update unbound_installer.sh\n' "${COLOR_GREEN}" "${COLOR_WHITE}"
				fi
				[ -n "$(pidof unbound)" ] && printf '\n%bs%b = Display unbound statistics\n' "${COLOR_GREEN}" "${COLOR_WHITE}"
				
				printf '\n%be%b = Exit Script\n' "${COLOR_GREEN}" "${COLOR_WHITE}"
				printf '\n%bOption ==>%b ' "${COLOR_GREEN}" "${COLOR_WHITE}"
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
					printf '%bInvalid Option%b %s%b Please enter a valid option\n' "$COLOR_RED" "$COLOR_GREEN" "$menu1" "$COLOR_WHITE"
				;;
			esac
		done
}

validate_removal () {
		while true; do
			printf '\nIMPORTANT: %bThe router will need to reboot in order to complete the removal of unbound%b\n\n' "${COLOR_RED}" "${COLOR_WHITE}"
			printf '%by%b = Are you sure you want to uninstall unbound?\n' "${COLOR_GREEN}" "${COLOR_WHITE}"
			printf '%bn%b = Cancel\n' "${COLOR_GREEN}" "${COLOR_WHITE}"
			printf '%be%b = Exit Script\n' "${COLOR_GREEN}" "${COLOR_WHITE}"
			printf '\n%bOption ==>%b ' "${COLOR_GREEN}" "${COLOR_WHITE}"
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
					printf '%bInvalid Option%b %s%b Please enter a valid option\n' "$COLOR_RED" "$COLOR_GREEN" "$menu3" "$COLOR_WHITE"
				;;
			esac
		done
}
Chk_Entware () {
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
is_dir_empty () {
		DIR="$1"
		cd "$DIR" || return 1
		set -- .[!.]* ; test -f "$1" && return 1
		set -- ..?* ; test -f "$1" && return 1
		set -- * ; test -f "$1" && return 1
		return 0
}
check_dnsmasq_parms () {
		if [ -s "/etc/dnsmasq.conf" ]; then  # dnsmasq.conf file exists
			for DNSMASQ_PARM in "server=127.0.0.1#53535"; do
				if grep -q "$DNSMASQ_PARM" "/etc/dnsmasq.conf"; then  # see if line exists
					printf 'Required dnsmasq parm %b%s%b found in /etc/dnsmasq.conf\n' "${COLOR_GREEN}" "$DNSMASQ_PARM" "${COLOR_WHITE}"
					continue #line found in dnsmasq.conf, no update required to /jffs/configs/dnsmasq.conf.add
				fi
				if [ -s "/jffs/configs/dnsmasq.conf.add" ]; then
					if grep -q "$DNSMASQ_PARM" "/jffs/configs/dnsmasq.conf.add"; then  # see if line exists
						#printf '%b%s%b found in /jffs/configs/dnsmasq.conf.add\n' "${COLOR_GREEN}" "$DNSMASQ_PARM" "${COLOR_WHITE}"
						:
					else
						printf 'Adding %b%s%b to /jffs/configs/dnsmasq.conf.add\n' "${COLOR_GREEN}" "$DNSMASQ_PARM" "${COLOR_WHITE}"
						printf '%s\n' "$DNSMASQ_PARM" >> /jffs/configs/dnsmasq.conf.add
					fi
				else
					printf 'Adding %b%s%b to /jffs/configs/dnsmasq.conf.add\n' "${COLOR_GREEN}" "$DNSMASQ_PARM" "${COLOR_WHITE}"
					printf '%s\n' "$DNSMASQ_PARM" > /jffs/configs/dnsmasq.conf.add
				fi
			done
		else
			echo "dnsmasq.conf file not found in /etc. dnsmasq appears to not be configured on your router. Check router configuration"
			exit 1
		fi
}
check_dnsmasq_postconf () {
		if [ -s "/jffs/scripts/dnsmasq.postconfX" ]; then  # dnsmasq.conf file exists
			for DNSMASQ_PARM in "server=127.0.0.1#53535"; do
				if grep -q "$DNSMASQ_PARM" "/jffs/scripts/dnsmasq.postconfX"; then  # see if line exists
					printf 'Required dnsmasq parm %b%s%b found in /etc/dnsmasq.conf\n' "${COLOR_GREEN}" "$DNSMASQ_PARM" "${COLOR_WHITE}"
					continue #line found in dnsmasq.conf, no update required to /jffs/configs/dnsmasq.conf.add
				fi
				if [ -s "/jffs/scripts/dnsmasq.postconfX" ]; then
					if grep -q "$DNSMASQ_PARM" "/jffs/scripts/dnsmasq.postconfX"; then  # see if line exists
						printf '%b%s%b found in /jffs/scripts/dnsmasq.postconfX\n' "${COLOR_GREEN}" "$DNSMASQ_PARM" "${COLOR_WHITE}"
					else
						printf 'Adding %b%s%b to /jffs/scripts/dnsmasq.postconfX\n' "${COLOR_GREEN}" "$DNSMASQ_PARM" "${COLOR_WHITE}"
						printf '%s\n' "$DNSMASQ_PARM" >> /jffs/scripts/dnsmasq.postconfX
					fi
				else
					printf 'Adding %b%s%b to /jffs/scripts/dnsmasq.postconfX\n' "${COLOR_GREEN}" "$DNSMASQ_PARM" "${COLOR_WHITE}"
					printf '%s\n' "$DNSMASQ_PARM" > /jffs/scripts/dnsmasq.postconfX
				fi
			done
		
		else
			{ echo "#!/bin/sh									
CONFIG=\$1								
source /usr/sbin/helper.sh					
pc_delete \"servers-file\" \$CONFIG			
pc_delete \"no-negcache\" \$CONFIG		
pc_delete \"domain-needed\" \$CONFIG			
pc_delete \"bogus-priv\" \$CONFIG						
pc_replace \"cache-size=1500\" \"cache-size=0\" \$CONFIG 
pc_append \"server=127.0.0.1#53535\" \$CONFIG"; }			> /jffs/scripts/dnsmasq.postconfX
		fi
}
create_required_directories () {
		for DIR in  "/opt/etc/unbound" "/opt/var/lib/unbound" "/opt/var/log"; do
			if [ ! -d "$DIR" ]; then
				if mkdir -p "$DIR" >/dev/null 2>&1; then
					printf "Created project directory %b%s%b\\n" "${COLOR_GREEN}" "${DIR}" "${COLOR_WHITE}"
					[ "$DIR" == "/opt/etc/unbound" ] && chown nobody /opt/etc/unbound
				else
					printf "Error creating directory %b%s%b. Exiting $(basename "$0")\\n" "${COLOR_GREEN}" "${DIR}" "${COLOR_WHITE}"
					exit 1
				fi
			fi
		done
}
make_backup () {
		DIR="$1"
		FILE="$2"
		TIMESTAMP="$(date +%Y-%m-%d_%H-%M-%S)"
		BACKUP_FILE_NAME="${FILE}.${TIMESTAMP}"
		if [ -f "$DIR/$FILE" ]; then
			if ! mv "$DIR/$FILE" "$DIR/$BACKUP_FILE_NAME" >/dev/null 2>&1; then
				printf 'Error backing up existing %b%s%b to %b%s%b\n' "$COLOR_GREEN" "$FILE" "$COLOR_WHITE" "$COLOR_GREEN" "$BACKUP_FILE_NAME" "$COLOR_WHITE"
				printf 'Exiting %s\n' "$(basename "$0")"
				exit 1
			else
				printf 'Existing %b%s%b found\n' "$COLOR_GREEN" "$FILE" "$COLOR_WHITE"
				printf '%b%s%b backed up to %b%s%b\n' "$COLOR_GREEN" "$FILE" "$COLOR_WHITE" "$COLOR_GREEN" "$BACKUP_FILE_NAME" "$COLOR_WHITE"
			fi
		fi
}
download_file () {
		DIR="$1"
		FILE="$2"
		STATUS="$(curl --retry 3 -sL -w '%{http_code}' "$GITHUB_DIR/$FILE" -o "$DIR/$FILE")"
		if [ "$STATUS" -eq "200" ]; then
			printf '\n\t%b%s%b downloaded successfully\n' "$COLOR_GREEN" "$FILE" "$COLOR_WHITE"
		else
			printf '\n%b%s%b download failed with curl error %s\n\n' "\n\t\a$COLOR_RED" "$FILE" "$COLOR_RED" "$STATUS"
			printf 'Rerun %binstall_unbound.sh%b and select the %bRemove Existing unbound Installation%b option\n' "$COLOR_GREEN" "$COLOR_WHITE" "$COLOR_GREEN" "$COLOR_WHITE"
			exit 1
		fi
}
S61unbound_update () {
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
update_wan_and_resolv_settings () {
		# Update Connect to DNS Server Automatically
		nvram set wan_dnsenable_x="0"
		nvram set wan0_dnsenable_x="0"

		LAN_IP="$(nvram get lan_ipaddr)"
		DNS1="$LAN_IP"
		NAMESERVER="$LAN_IP"
		SERVER="$LAN_IP"
		RTR_IP="$(nvram get ipv6_rtr_addr)"

		# Set firmware nameserver and server entries
		echo "nameserver $NAMESERVER" > /tmp/resolv.conf
		echo "server=${SERVER}" > /tmp/resolv.dnsmasq

		# Set DNS1 based on user option
		nvram set wan0_dns="$DNS1"
		nvram set wan_dns="$DNS1"
		nvram set wan_dns1_x="$DNS1"
		nvram set wan0_xdns="$DNS1"
		nvram set wan0_dns1_x="$DNS1"

		# Set DNS2 to null
		nvram set wan_dns2_x=""
		nvram set wan0_dns2_x=""

		if [ "$(nvram get ipv6_service)" != "disabled" ]; then
			nvram set ipv6_dnsenable="0"
			nvram set ipv61_dnsenable="0"
			echo "server=${RTR_IP}" >> /tmp/resolv.dnsmasq
			nvram set ipv6_dns1="$RTR_IP"
			nvram set ipv6_dns2=""
			nvram set ipv6_dns3=""
			nvram set ipv61_dns1="$RTR_IP"
			nvram set ipv61_dns2=""
			nvram set ipv61_dns3=""
		fi

		# Choose DNSSEC setting
		nvram set dnssec_enable="0"
		DNSMASQ_PARM="proxy-dnssec"
		while true; do
			printf '\n\nWould you like to cache DNSSEC Authenticated Data? (proxy-dnssec)\n'
			echo "[1]  --> Yes"
			echo "[2]  --> No"
			echo
			printf "[1-2]: "
			read -r "menu2"
			echo
			case "$menu2" in
				1)
					if grep -q "$DNSMASQ_PARM" "/jffs/configs/dnsmasq.conf.add"; then
						printf '%b%s%b found in /jffs/configs/dnsmasq.conf.add\n' "${COLOR_GREEN}" "$DNSMASQ_PARM" "${COLOR_WHITE}"
					else
						printf 'Adding %b%s%b to /jffs/configs/dnsmasq.conf.add\n' "${COLOR_GREEN}" "$DNSMASQ_PARM" "${COLOR_WHITE}"
						printf '%s\n' "$DNSMASQ_PARM" >> /jffs/configs/dnsmasq.conf.add
					fi
					break
				;;
				2)
					if grep -q "$DNSMASQ_PARM" "/jffs/configs/dnsmasq.conf.add"; then
						sed -i "\\~$DNSMASQ_PARM~d" "/jffs/configs/dnsmasq.conf.add"
					fi
					break
				;;
				*)
					echo "[*] $menu2 Isn't An Option!"
				;;
			esac
		done

		# Choose IPTables Setting
		while true; do
			printf '\n\nWould you like to force all client DNS requests through unbound (DNSFilter)\n'
			echo "[1]  --> Yes"
			echo "[2]  --> No"
			echo
			printf "[1-2]: "
			read -r "menu2"
			echo
			case "$menu2" in
				1)
						nvram set dnsfilter_custom1=""
						nvram set dnsfilter_custom2=""
						nvram set dnsfilter_custom3=""
						nvram set dnsfilter_enable_x="1"
						nvram set dnsfilter_mode="11"
						nvram set dnsfilter_rulelist=""
						nvram set dnsfilter_rulelist1=""
						nvram set dnsfilter_rulelist2=""
						nvram set dnsfilter_rulelist3=""
						nvram set dnsfilter_rulelist4=""
						nvram set dnsfilter_rulelist5=""
						break
				;;
				2)
						nvram set dnsfilter_enable_x="0"
						break
				;;
				*)
					echo "[*] $menu2 Isn't An Option!"
				;;
			esac
		done

		# Commit nvram values
		nvram commit

		# IPv6 Prefix Check
		if [ ! -f "/jffs/scripts/nat-start" ]; then
			echo "#!/bin/sh" > /jffs/scripts/nat-start
			echo >> /jffs/scripts/nat-start
		elif [ -f "/jffs/scripts/nat-start" ] && ! head -1 /jffs/scripts/nat-start | grep -qE "^#!/bin/sh"; then
			sed -i '1s~^~#!/bin/sh\n~' /jffs/scripts/nat-start
		fi
		chmod 755 /jffs/scripts/nat-start
		sed -i '\~ unbound Installer~d' /jffs/scripts/nat-start
		echo "sh /jffs/scripts/install_unbound.sh checkipv6 # unbound Installer" >> /jffs/scripts/nat-start

}
exit_message () {
		rm -rf /tmp/unbound.lock
		echo
		exit 0
}

update_installer () {
	if [ "$localmd5" != "$remotemd5" ]; then
		download_file /jffs/scripts unbound_installer_v1.0beta.sh
		#***********************************Temporary hack*************************************************
		echo -e "\t$FILE --> '/jffs/scripts/unbound_installer.sh'"
		chmod 755 /jffs/scripts/$FILE;mv /jffs/scripts/$FILE /jffs/scripts/unbound_installer.sh;dos2unix /jffs/scripts/unbound_installer.sh
		#**************************************************************************************************
		printf '\nUpdate Complete! %s\n' "$remotemd5"
	else
		printf '\nunbound_installer.sh is already the latest version. %s\n' "$localmd5"
	fi

	exit_message
}
Customise_config() {

	 echo "Customising '/opt/etc/unbound/unbound.conf'"
	 
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
	 
	 echo "Retrieving '/opt/var/lib/unbound/root-hints'"
	 curl -o /opt/var/lib/unbound/root.hints https://www.internic.net/domain/named.cache
	 [ $? -eq 0 ] && sed -i 's~# root\-hints:.*~root\-hints: \"/opt/var/lib/unbound/root\.hints\"~' /opt/etc/unbound/unbound.conf
	 
}
Enable_unbound_statistics() {
		# unbound-control-setup uses 'setup in directory /opt/var/lib/unbound' ???
		# generating unbound_server.key
		# Generating RSA private key, 3072 bit long modulus
		# ....................................++++
		# .......................................................................................................................................................................++++
		# e is 65537 (0x10001)
		# generating unbound_control.key-file
		echo "Initialising 'unbound-control-setup'"
		unbound-control-setup
		
		echo "Enabling unbound 'remote-control:' in '/opt/etc/unbound/unbound.conf'"
		sed -ibak '/remote-control:/acontrol-enable: yes \
control-interface: 127\.0\.0\.1 \
server-key-file: "/opt/var/lib/unbound/unbound_server\.key" \
server-cert-file: "/opt/var/lib/unbound/unbound_server\.pem" \
control-key-file: "/opt/var/lib/unbound/unbound_control\.key" \
control-cert-file: "/opt/var/lib/unbound/unbound_control\.pem" \
control-port: 953' /opt/etc/unbound/unbound.conf
		echo "Use 'unbound-control stats_noreset' to monitor unbound performance"
}
Check_SWAP() {
	local SWAPSIZE=$(grep "SwapTotal" /proc/meminfo | awk '{print $2}') 
	[ $SWAPSIZE -gt 0 ] && { echo $SWAPSIZE; return 0;} || { echo $SWAPSIZE; return 1; }
}
remove_existing_installation () {
		echo "Starting removal of unbound"

		# Kill unbound process
		pidof unbound | while read -r "spid" && [ -n "$spid" ]; do
			kill "$spid"
		done

		# Remove the unbound package
		Chk_Entware unbound
		if [ "$READY" -eq "0" ]; then
			echo "Existing unbound package found. Removing unbound"
			if opkg remove unbound-control-setup unbound-control unbound-anchor unbound-daemon; then echo "unbound successfully removed"; else echo "Error occurred when removing unbound"; fi
			#if opkg remove haveged; then echo "haveged successfully removed"; else echo "Error occurred when removing haveged"; fi
		else
			echo "Unable to remove unbound - 'unbound' not installed?"
		fi

		# Remove entries from /jffs/configs/dnsmasq.conf.add
		if [ -s "/jffs/configs/dnsmasq.conf.add" ]; then  # file exists
			for DNSMASQ_PARM in "^server=127\.0\.0\.1*#53535"; do
				if [ -n "$(grep -oE "$DNSMASQ_PARM" /jffs/configs/dnsmasq.conf.add)" ]; then  # see if line exists
					sed -i "\\~$DNSMASQ_PARM~d" "/jffs/configs/dnsmasq.conf.add"
				fi
			done
		fi
		
		service restart_dnsmasq >/dev/null 2>&1			# Just in case ctrl-c to prevent reboot!

		# Purge unbound directories
		for DIR in  "/opt/etc/unbound" "/opt/var/lib/unbound"; do
			if [ -d "$DIR" ]; then
				if ! rm "$DIR"/* >/dev/null 2>&1; then
					printf '\nNo files found to remove in %b%s%b\n' "$COLOR_GREEN" "$DIR" "$COLOR_WHITE"
				fi
				if ! rmdir "$DIR" >/dev/null 2>&1; then
					printf '\nError trying to remove %b%s%b\n' "$COLOR_GREEN" "$DIR" "$COLOR_WHITE"
				else
					printf '\n%b%s%b folder and all files removed\n' "$COLOR_GREEN"  "$DIR" "$COLOR_WHITE"
				fi
			else
				printf '\n%b%s%b folder does not exist. No directory to remove\n' "$COLOR_GREEN" "$DIR" "$COLOR_WHITE"
			fi
		done

		# Remove /opt/var/log/unbound.log file
		if [ -f "/opt/var/log/unbound.log" ]; then  # file exists
			rm "/opt/var/log/unbound.log"
		fi

		# Remove /jffs/configs/resolv.dnsmasq
		# if [ -f "/jffs/configs/resolv.dnsmasq" ]; then  # file exists
			# rm "/jffs/configs/resolv.dnsmasq"
		# fi

		# remove file /opt/etc/init.d/S61unbound
		if [ -d "/opt/etc/init.d" ]; then
			/opt/bin/find /opt/etc/init.d -type f -name S61unbound\* -delete
		fi

		#remove /jffs/scripts/nat-start
		if grep -qF "unbound Installer" /jffs/scripts/nat-start; then
			sed -i '\~ unbound Installer~d' /jffs/scripts/nat-start
		fi

		# # Default DNS1 to Cloudflare 1.1.1.1
		# DNS1="1.1.1.1"
		# nvram set wan0_dns="$DNS1"
		# nvram set wan_dns="$DNS1"
		# nvram set wan_dns1_x="$DNS1"
		# nvram set wan0_xdns="$DNS1"
		# nvram set wan0_dns1_x="$DNS1"
		# nvram set wan0_dnsenable_x="1"

		# if [ "$(nvram get ipv6_service)" != "disabled" ]; then
			# IPV6_DNS1="2606:4700:4700::1111"
			# nvram set ipv6_dns1="$IPV6_DNS1"
			# nvram set ipv61_dns1="$IPV6_DNS1"
			# nvram set ipv6_dnsenable="1"
		# fi

		#nvram set dnsfilter_enable_x="0"

		#nvram commit

		# Remove /opt symlink
		rm -rf "/opt/bin/install_unbound" "/jffs/scripts/install_unbound.sh"

		# Reboot router to complete uninstall of unbound
		echo "Uninstall of unbound completed."
		
		echo -e "\nThe router will now $COLOR_RED REBOOT $COLOR_WHITE to finalize the removal of unbound"
		echo -e "After the $COLOR_RED REBOOT $COLOR_WHITE, review the DNS settings on the WAN GUI and adjust if necessary"
		echo
		echo -e "Press$COLOR_RED Y$COLOR_WHITE to$COLOR_RED REBOOT $COLOR_WHITE or press$COLOR_GREEN ENTER to ABORT"
		read -r "CONFIRM_REBOOT"
		[ "$CONFIRM_REBOOT" == "Y" ] && { echo -e $COLOR_RED"\a\n\n\tREBOOTing....."; service start_reboot; } || echo -e $COLOR_GREEN"\n\tReboot ABORTED\n"$COLOR_WHITE
}
install_unbound () {
		if [ -d "/jffs/dnscrypt" ] || [ -f "/opt/sbin/dnscrypt-proxy" ]; then
			echo "Warning! DNSCrypt installation detected"
			printf 'Please remove this script to continue installing unbound\n\n'
			exit 1
		fi
		echo
		if Chk_Entware; then
			if opkg update >/dev/null 2>&1; then
				echo "Entware package list successfully updated";
			else
				echo "An error occurred updating Entware package list"
				exit 1
			fi
		else
			echo "You must first install Entware before proceeding see 'amtm'"
			printf 'Exiting %s\n' "$(basename "$0")"
			exit 1
		fi

		# # Xentrk revision needed to bypass false positive that unbound is installed if /opt/var/cache/unbound
		# # and /opt/etc/unbound exists. When unbound is removed via the command line, the entware directory
		# # is not deleted.

		# # check for unbound folders with no files
		# for DIR in /opt/etc/unbound /opt/var/lib/unbound; do
			# if [ -d "$DIR" ]; then
				# if ! is_dir_empty "$DIR"; then
					# if ! rmdir "$DIR" >/dev/null 2>&1; then
						# printf '\nError trying to remove %b%s%b\n' "$COLOR_GREEN" "$DIR" "$COLOR_WHITE"
					# else
						# printf '\norphaned %b%s%b folder removed\n' "$COLOR_GREEN"  "$DIR" "$COLOR_WHITE"
					# fi
				# fi
			# fi
		# done
		if opkg install unbound-daemon unbound-control unbound-control-setup unbound-anchor --force-downgrade; then
			echo "unbound Entware packages 'unbound-daemon unbound-control unbound-control-setup unbound-anchor' successfully installed"
		else
			echo "An error occurred installing unbound"
			exit 1
		fi
		if opkg install haveged; then
			echo "Haveged successfully updated"
		else
			echo "An error occurred updating Haveged"
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

		if [ -d "/opt/bin" ] && [ ! -L "/opt/bin/install_unbound" ]; then
			ln -s /jffs/scripts/install_unbound.sh /opt/bin/install_unbound
		fi
			
		echo "Linking '/opt/etc/unbound/unbound.conf' --> '/opt/var/lib/unbound/unbound.conf'"
		ln -s /opt/etc/unbound/unbound.conf /opt/var/lib/unbound/unbound.conf		# Hack to retain '/opt/etc/unbound' for configs
		
		Enable_unbound_statistics
		
		S61unbound_update		
		Customise_config
		/opt/etc/init.d/S61unbound restart				# Will also restart dnsmasq
		
		#service restart_dnsmasq >/dev/null 2>&1	
		#service restart_firewall >/dev/null 2>&1

		if pidof unbound >/dev/null 2>&1; then
			echo "Installation of unbound completed"
		else
			echo "Warning! Unsuccesful installation of unbound detected"
			printf 'Rerun %binstall_unbound.sh%b and select the %bRemove%b option to backout changes\n' "$COLOR_GREEN" "$COLOR_WHITE" "$COLOR_GREEN" "$COLOR_WHITE"
		fi
		
		# CheckCreate Swap file
		[ $(Check_SWAP) -eq 0 ] && echo $COLOR_RED"\a\n\tWarning SWAP file is not configured - use amtm to create one!" || echo "Swapfile="$(grep "SwapTotal" /proc/meminfo | awk '{print $2" "$3}')		
		
		#	DNSFilter: ON - mode Router 
		if [ $(nvram get dnsfilter_enable_x) -eq 0 ];then 
			echo -e $COLOR_RED"\a\n\t***ERROR DNS Filter is OFF! - $COLOR_WHITE see http://$(nvram get lan_ipaddr)/DNSFilter.asp Enable DNS-based Filtering" 
		else
			#	DNSFilter: ON - Mode Router ? 
			[ $(nvram get dnsfilter_mode) != "11" ] && echo -e $COLOR_RED"\a\n\t***ERROR DNS Filter is NOT = 'Router' see http://$(nvram get lan_ipaddr)/DNSFilter.asp"$COLOR_WHITE
		fi
		
		#	Tools/Other WAN DNS local cache: NO # for the FW Merlin development team, it is desirable and safer by this mode. 
		[ $(nvram get nvram get dns_local_cache) != "0" ] && echo -e $COLOR_RED"\a\n\t***ERROR WAN: Use local caching DNS server as system resolver=YES $COLOR_WHITE see http://$(nvram get lan_ipaddr)/Tools_OtherSettings.asp ->Advanced Tweaks and Hacks"$COLOR_WHITE
		
		#	Configure NTP server Merlin
		[ $(nvram get ntpd_enable) == "0" ] && echo -e $COLOR_RED"\a\n\t***ERROR Enable local NTP server=NO $COLOR_WHITE see http://$(nvram get lan_ipaddr)/Advanced_System_Content.asp ->Basic Config"$COLOR_WHITE
		
		exit_message
}
#=============================================Main=============================================================
# shellcheck disable=SC2068
Main() { true; } # Syntax that is Atom Shellchecker compatible!

clear
Check_Lock "$1"

welcome_message "$@"

rm -rf /tmp/unbound.lock
