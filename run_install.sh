#!/usr/bin/env bash
#
# Usage:   ./run_installer.sh <cf_release_version> <ip address>

cf_release_version="$1"
ip_address="$2"

# Install dependency
gem install colored --no-ri --no-rdoc

# Fix nginx bug
sed -i 's/5000m/10000m/g' /var/vcap/data/jobs/director/fake-job-template-version-*/config/nginx.conf
monit restart director_nginx

# Apply iptables rules
iptables -t nat -A PREROUTING -d "$ipaddress/32" -p tcp -m tcp --dport 80 -j DNAT --to-destination 10.244.0.34:80
iptables -t nat -A PREROUTING -d "$ipaddress/32" -p tcp -m tcp --dport 443 -j DNAT --to-destination 10.244.0.34:443
iptables -t nat -A PREROUTING -d "$ipaddress/32" -p tcp -m tcp --dport 4443 -j DNAT --to-destination 10.244.0.34:4443

# Save iptables
/sbin/iptables-save > /etc/iptables.rules

# Restore on restart
if ! grep iptables-restore /etc/network/interfaces.d/eth0.cfg; then
  echo "  pre-up iptables-restore < /etc/iptables.rules" >> /etc/network/interfaces.d/eth0.cfg
fi

# Run bosh might
cd $HOME/workspace
ruby ./bosh-might/bosh-might.rb "$cf_release_version" "$ip_address"
