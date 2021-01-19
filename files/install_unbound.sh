#! /bin/sh
CONFIG_DIR="/opt/var/lib/unbound/"
EXEC_DIR="/opt/etc/init.d/"
SCRIP_DIR="/jffs/scripts/"
echo "Installing unbound and suricata with Entware.."
opkg update
opkg install \
  dos2unix \
	unbound-daemon \
	coreutils-nproc \
	unbound-control \
	unbound-control-setup \
  unbound-anchor \
	unbound-checkconf \
	haveged \
	fake-hwclock \
  ca-bundle

echo "Setting unbound..."
mkdir /opt/var/lib/unbound
chown nobody /opt/var/lib/unbound
/opt/sbin/unbound-anchor -a ${CONFIG_DIR}root.key
unbound-control-setup

echo "Get root DNS server..."
curl -o ${CONFIG_DIR}root.hints https://www.internic.net/domain/named.cache

echo "Get necessary files..."
curl -o ${EXEC_DIR}S02haveged https://raw.githubusercontent.com/rgnldo/knot-resolver-suricata/master/files/S02haveged
curl -o ${EXEC_DIR}S61unbound https://raw.githubusercontent.com/rgnldo/knot-resolver-suricata/master/files/S61unbound
curl -o ${SCRIP_DIR}ini_unbound.sh https://raw.githubusercontent.com/rgnldo/knot-resolver-suricata/master/files/ini_unbound.sh
curl -o ${SCRIP_DIR}gen_unbound.sh https://raw.githubusercontent.com/rgnldo/knot-resolver-suricata/master/files/gen_unbound.sh
curl -o ${SCRIP_DIR}gen_adblock.sh https://raw.githubusercontent.com/rgnldo/knot-resolver-suricata/master/files/gen_adblock.sh
chmod 755 ${EXEC_DIR}S02haveged
dos2unix ${EXEC_DIR}S02haveged
chmod 755 ${EXEC_DIR}S61unbound
dos2unix ${EXEC_DIR}S61unbound
chmod 755 ${SCRIP_DIR}ini_unbound.sh
dos2unix ${SCRIP_DIR}ini_unbound.sh
chmod 755 ${EXEC_DIR}gen_unbound.sh
dos2unix ${EXEC_DIR}gen_unbound.sh
chmod 755 ${EXEC_DIR}gen_adblock.sh
dos2unix ${EXEC_DIR}gen_adblock.sh

echo "start services..."
sh ${EXEC_DIR}gen_unbound.sh
sh ${EXEC_DIR}gen_adblock.sh
/opt/etc/init.d/rc.unslung restart
