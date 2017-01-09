mac2vendor/OUI-lookup API for static webservers
===============================================

This POSIX shell script fetches the latest OUI file,  
parses it and generates a filesystem-hierarchy which  
can be used from a static webserver for a very simple  
mac2vendor API, e.g. for the mac-address 3C:D9:2B:xx:xx:xx

    # curl http://yourserver/oui/3c/d9/2b
    Hewlett Packard

on your server execute this (needs ~6 min / 11 mbytes disk)

    # ./update.sh /var/www/oui

this repository is updated once a day. You can  
find a sample shell-function mac2vendor() here:

https://github.com/bittorf/kalua/blob/master/openwrt-addons/etc/kalua/net#L1306

This poor mens API make sense on embedded or IoT-devices  
with a low amount of storage. You can try it on this demo-server:

    # curl http://intercity-vpn.de/oui/3c/d9/2b

For the lazy people there is also an up-to-date tar.xz:

    # mkdir /var/www/oui && cd /var/www/oui
    # wget http://intercity-vpn.de/oui/oui.tar.xz
    # tar xJf oui.tar.xz

Ready.


cronjob on server:
------------------

```
# once: git config --global user.name 'bot'
# once: git config --global user.email 'bot@yourdomain'
```
    # while :;do rm oui.txt; ./update.sh /var/www/oui; git push; sleep 86400; done

TODO
----

* add example client-implementations for popular languages
* autogenerate 'mac2vendor.c' with compression, so everything should fit into a 250k binary
  * show uniq printable chars for organizations:
```
# grep '(base 16)' oui.txt |
   while read L; do set -- $L; shift 3; echo $*; done |
    sort -u |
     tr -cd '\11\12\15\40-\176' |
      sed 's/\(.\)/\1\n/g' |
       sort -u
79
```
