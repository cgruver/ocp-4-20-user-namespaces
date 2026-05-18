#!/usr/bin/env bash

sudo /usr/sbin/ip link set dev eth0 down
sudo /usr/sbin/ip link set dev eth0 address aa:bb:cc:01:02:03
sudo /usr/sbin/ip link set dev eth0 up

exec "$@"