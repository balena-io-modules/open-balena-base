#!/bin/bash

INSTANCE_ID=`wget --tries=1 --timeout=1 --quiet --output-document=- http://169.254.169.254/latest/meta-data/instance-id`
AVAILABILITY_ZONE=`wget --tries=1 --timeout=1 --quiet --output-document=- http://169.254.169.254/latest/meta-data/placement/availability-zone`
SERVICE=`wget --tries=1 --timeout=1 --quiet --output-document=- http://169.254.169.254/latest/user-data | awk -F "=" '/ service/ {print $2}'`

echo "Hostname \"$AVAILABILITY_ZONE.$INSTANCE_ID.$SERVICE\"" > /opt/collectd/etc/collectd.conf.d/user.conf
