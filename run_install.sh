#!/usr/bin/env bash

cf_release_version="$1"
ip_address="$2"

# Install dependency
gem install colored --no-ri --no-rdoc

# Fix nginx bug
sed -i 's/5000m/10000m/g' /var/vcap/data/jobs/director/fake-job-template-version-*/config/nginx.conf
monit restart director_nginx


