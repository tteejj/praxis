#!/bin/sh
# Wait for wlan0 to be loaded by the firmware
for i in 1
2
3
4
5
6
7
8
9
10; do
    [ -d /sys/class/net/wlan0 ] && break
    sleep 1
done
# Copy our custom config and start wpa_supplicant
cp /usr/local/etc/wpa_supplicant.conf /etc/wpa_supplicant.conf
wpa_supplicant -B -i wlan0 -c /etc/wpa_supplicant.conf
udhcpc -i wlan0 -b -p /var/run/udhcpc.wlan0.pid
