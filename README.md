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

For the lazy people there is also an up-to-date 1.6mb-tar.xz:

    # mkdir /var/www/oui && cd /var/www/oui
    # wget http://intercity-vpn.de/oui/oui.tar.xz
    # tar xJf oui.tar.xz

Ready.


example mac2vendor for online search (posix shell function)
-----------------------------------------------------------

```
#!/bin/sh

mac2vendor()
{
  local vendor cachefile mac=$1
  local cachedir="/dev/shm"

  set -- $( echo "${mac:-aa,bb,cc}" | tr 'A-F' 'a-f' | tr -c '0-9a-f' ' ' )
  cachefile="$cachedir/mac2vendor-$1-$2-$3"

  case "${1}${2}${3}" in    # is 802.11p OCB or 2nd bit of 1st byte set?
    ffffff|?'2'*|?'3'*|?'6'*|?'7'*|?'a'*|?'b'*|?'e'*|?'f'*|?'A'*|?'B'*|?'E'*|?'F'*) echo locally_administered && return
  esac

  cat "$cachefile" 2>/dev/null || {
    vendor="$( wget -qO - "http://intercity-vpn.de/oui/$1/$2/$3" | head -n1 )"
    [ "$vendor" ] && echo "$vendor" && echo "$vendor" >"$cachefile"
  }
}

$ mac2vendor 1CED6F
AVM GERMANY
$ mac2vendor 02:ca:ff:ee:ba:be
locally_administered
```


example mac2vendor for offline search (posix shell function)
------------------------------------------------------------

```
#!/bin/sh

mac2vendor()	# see normalize_vendors.sh for 'mac-vendor.txt.gz' a ~250k file
{
  local mac=$1
  set -- $( echo "${mac:-AA,BB,CC}" | tr 'a-f' 'A-F' | tr -c '0-9A-F' ' ' )

  case "${1}${2}${3}" in    # is 802.11p OCB or 2nd bit of 1st byte set?
    ffffff|?'2'*|?'3'*|?'6'*|?'7'*|?'a'*|?'b'*|?'e'*|?'f'*|?'A'*|?'B'*|?'E'*|?'F'*) echo locally_administered && return
  esac

  zgrep -w "${1}${2}${3}" mac-vendor.txt.gz | cut -f2
}

$ mac2vendor 1CED6F
AVM GERMANY
$ mac2vendor 02:ca:ff:ee:ba:be
locally_administered
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
* upload online and offline data to CDN
```
