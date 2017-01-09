poor mens mac2vendor (or OUI-lookup) API for static webservers
==============================================================

This POSIX shell script fetches the latest OUI file,
parses it and generates a filesystem-hierarchy which
can be used from a static webserver for a very simple
mac2vendor API, e.g. for the mac-address 3C:D9:2B:xx:xx:xx

    # curl http://yourserver/oui/3c/d9/2b
    Hewlett Packard

on your server execute this (needs ~6 min / 11 mbytes disk)

    # ./update.sh /var/www/oui


this repository is updated once a day.

You can find a sample shell-function mac2vendor() e.g. here:
https://github.com/bittorf/kalua/blob/master/openwrt-addons/etc/kalua/net#L1306

You can try it on this demo-server:

    # curl http://intercity-vpn.de/oui/3c/d9/2b

For the lazy people there is also an up-to-date tar.xz:

    # mkdir /var/www/oui && cd /var/www/oui
    # wget http://intercity-vpn.de/oui/oui.tar.xz
    # tar xJf oui.tar.xz

Ready.


TODO
----

autogenerate 'mac2vendor.c' with internal clever compression,
so everything should fit into a 250k binary.
