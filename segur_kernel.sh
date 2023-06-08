#!/bin/bash

echo "Adicionando opções de segurança no kernel"
# Ignore ICMP redirects
echo "net.ipv6.conf.all.accept_redirects=0" >> /etc/sysctl.d/99-sysctl.conf
echo "net.ipv6.conf.default.accept_redirects=0" >> /etc/sysctl.d/99-sysctl.conf
echo "net.ipv4.conf.all.send_redirects=0" >> /etc/sysctl.d/99-sysctl.conf
echo "net.ipv4.conf.default.send_redirects=0" >> /etc/sysctl.d/99-sysctl.conf

# Ignore ICMP broadcast requests
echo "net.ipv4.icmp_echo_ignore_broadcasts=1" >> /etc/sysctl.d/99-sysctl.conf

# Disable source packet routing
echo "net.ipv4.conf.all.accept_source_route=0" >> /etc/sysctl.d/99-sysctl.conf
echo "net.ipv6.conf.all.accept_source_route=0" >> /etc/sysctl.d/99-sysctl.conf 
echo "net.ipv4.conf.default.accept_source_route=0" >> /etc/sysctl.d/99-sysctl.conf
echo "net.ipv6.conf.default.accept_source_route=0" >> /etc/sysctl.d/99-sysctl.conf


echo "net.core.default_qdisc=cake" >> /etc/sysctl.d/99-sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.d/99-sysctl.conf

echo "net.core.rmem_default=1048576" >> /etc/sysctl.d/99-sysctl.conf
echo "net.core.rmem_max=16777216" >> /etc/sysctl.d/99-sysctl.conf
echo "net.core.wmem_default=1048576" >> /etc/sysctl.d/99-sysctl.conf
echo "net.core.wmem_max=16777216" >> /etc/sysctl.d/99-sysctl.conf
echo "net.core.optmem_max=65536" >> /etc/sysctl.d/99-sysctl.conf
echo "net.ipv4.tcp_rmem=4096 1048576 2097152" >> /etc/sysctl.d/99-sysctl.conf
echo "net.ipv4.tcp_wmem=4096 65536 16777216" >> /etc/sysctl.d/99-sysctl.conf
echo "net.ipv4.udp_rmem_min=8192" >> /etc/sysctl.d/99-sysctl.conf
echo "net.ipv4.udp_wmem_min=8192" >> /etc/sysctl.d/99-sysctl.conf 

# Block SYN attacks
echo "net.ipv4.tcp_syncookies=1" >> /etc/sysctl.d/99-sysctl.conf
echo "net.ipv4.tcp_max_syn_backlog=2048" >> /etc/sysctl.d/99-sysctl.conf
echo "net.ipv4.tcp_synack_retries=2" >> /etc/sysctl.d/99-sysctl.conf
echo "net.ipv4.tcp_syn_retries=5" >> /etc/sysctl.d/99-sysctl.conf

# Log Martians
echo "net.ipv4.conf.all.log_martians=1" >> /etc/sysctl.d/99-sysctl.conf
echo "net.ipv4.icmp_ignore_bogus_error_responses=1" >> /etc/sysctl.d/99-sysctl.conf

# IP Spoofing protection
echo "net.ipv4.conf.all.rp_filter=1" >> /etc/sysctl.d/99-sysctl.conf
echo "net.ipv4.conf.default.rp_filter=1" >> /etc/sysctl.d/99-sysctl.conf

# Ignore ICMP broadcast requests
echo "net.ipv4.icmp_echo_ignore_broadcasts=1" >> /etc/sysctl.d/99-sysctl.conf

# IP Spoofing protection
echo "net.ipv4.conf.all.rp_filter=1" >> /etc/sysctl.d/99-sysctl.conf
echo "net.ipv4.conf.default.rp_filter=1" >> /etc/sysctl.d/99-sysctl.conf

# Hide kernel pointers
echo "kernel.kptr_restrict=2" >> /etc/sysctl.d/99-sysctl.conf 

# Enable panic on OOM
echo "vm.panic_on_oom=1" >> /etc/sysctl.d/99-sysctl.conf
