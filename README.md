mac2vendor/OUI-lookup API for static webservers
===============================================

This POSIX shell script fetches the latest OUI file,  
parses it and generates a filesystem-hierarchy which  
can be used from a static webserver for a very simple  
mac2vendor API, e.g. for the mac-address 3C:D9:2B:xx:xx:xx

    # curl http://yourserver/oui/3c/d9/2b
    Hewlett Packard

on your server execute this (needs ~6 min / 23 mbytes disk)

    # ./update.sh /var/www/oui

this repository is updated once a day.

This poor mens API make sense on embedded or IoT-devices  
with a low amount of storage. You can try it on this demo-server:

    # curl http://intercity-vpn.de/oui/3c/d9/2b
    # curl http://intercity-vpn.de/oui/3c/d9/2b.json

For the lazy people there is also an up-to-date tar.xz:

    # mkdir /var/www/oui && cd /var/www/oui
    # wget http://intercity-vpn.de/oui/oui.tar.xz
    # tar xJf oui.tar.xz

Ready.


example mac2vendor (posix shell function)
-----------------------------------------

```
#!/bin/sh

mac2vendor()
{
	local vendor cachefile mac=$1

	set -- $( echo "${mac:-aa,bb,cc}" | tr 'A-F' 'a-f' | tr -c '0-9a-f' ' ' )
	cachefile="/dev/shm/mac2vendor-$1-$2-$3"

	if [ -s "$cachefile" ]; then
		cat "$cachefile"
	else
		vendor="$( wget -qO - "http://intercity-vpn.de/oui/$1/$2/$3" | head -n1 )"
		[ -n "$vendor" ] && echo "$vendor" >"$cachefile" && echo "$vendor"
	fi
}

```

cronjob on server:
------------------

```
# once: git config --global user.name 'bot'
# once: git config --global user.email 'bot@yourdomain'
```
    # while :;do rm oui.txt; ./update.sh /var/www/oui; git push; sleep 86400; done

TODO
----

* add historical data from
  https://web.archive.org/web/19980515000000*/http://standards.ieee.org/regauth/oui/oui.txt
  https://web.archive.org/web/*/http://standards-oui.ieee.org/oui.txt
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
