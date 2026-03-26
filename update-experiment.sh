#!/bin/sh

set -e

WWWDIR="${1:-/var/www/oui}"
FILE="${2:-oui.txt}"
OPTION="$3"
OPTION_ARG="${4:-oui.sh}"

URL='https://standards-oui.ieee.org/oui/oui.txt'
FILE_FLAT="$FILE.flatdb.txt"
SHELLFILE="$OPTION_ARG"
STATS=$(mktemp)

log() { >&2 printf '%s | %s\n' "$(date)" "$1"; }

trap 'rm -f "$STATS"' EXIT

if test -f "$FILE" || wget --no-check-certificate -O "$FILE" "$URL"; then
	HASH_NEW="$( md5sum <"$FILE" )"
	test -f "$FILE_FLAT.hash" && read -r HASH_OLD <"$FILE_FLAT.hash"
	echo "$HASH_NEW" >"$FILE_FLAT.hash"
	test "$HASH_OLD" = "$HASH_NEW" && log "[OK] no changes in '$FILE'" && exit 0

	log "[OK] parsing '$FILE' with $( wc -l <"$FILE" ) lines..."

	mkdir -p "$WWWDIR"
	true >"$FILE_FLAT"

	if [ "$OPTION" = "build_shellscript" ]; then
		cat >"$SHELLFILE" << 'SHELLEOF'
#!/bin/sh
e(){ printf '%s\n' "$*";}
dq(){ printf '"%s"\n' "$*";}
case "$1" in
SHELLEOF
		chmod +x "$SHELLFILE"
	fi

	awk -v WWWDIR="$WWWDIR" -v FILE_FLAT="$FILE_FLAT" -v SHELLFILE="$SHELLFILE" -v OPTION="$OPTION" -v STATS="$STATS" '
	BEGIN {
		FS=" "
		vendor=""; addr1=""; addr2=""; country=""
		dir1=""; dir2=""; dir3=""; opath=""
		ALL=0; NEW=0
	}
	/^([0-9a-fA-F]{2}-){2}[0-9a-fA-F]{2}[[:space:]]+\(hex\)/ {
		gsub(/[^0-9a-fA-F]/, "", $1)
		mac = toupper($1)
		dir1 = substr(mac,1,2)
		dir2 = substr(mac,3,2)
		dir3 = substr(mac,5,2)
		opath = dir1 "/" dir2 "/" dir3
		vendor = ""
		for (i=3; i<=NF; i++) {
			gsub(/\r/, "", $i)
			vendor = (vendor ? vendor " " : "") $i
		}
		next
	}
	/^[0-9a-fA-F]{6}[[:space:]]+\(base 16\)/ { next }
	NF > 0 && vendor != "" {
		gsub(/\r/, "")
		sub(/^[[:space:]]+/, "")
		if ($0 == "") { vendor=""; next }
		if (!addr1) addr1 = $0
		else if (!addr2) addr2 = $0
		else if (!country) {
			country = $0
			if (!done[dir1 dir2]++) {
				system("mkdir -p \"" WWWDIR "/" dir1 "/" dir2 "\"")
			}
			printf "%s\n", vendor > (WWWDIR "/" opath)
			close(WWWDIR "/" opath)
			printf "{ \"vendorOUI\": \"%s-%s-%s\", \"vendorOUIbyte1\": \"%s\", \"vendorOUIbyte2\": \"%s\", \"vendorOUIbyte3\": \"%s\", \"vendorName\": \"%s\", \"vendorStreet\": \"%s\", \"vendorCity\": \"%s\", \"vendorCountry\": \"%s\" }\n",
				dir1, dir2, dir3, dir1, dir2, dir3, vendor, addr1, addr2, country > (WWWDIR "/" opath ".json")
			close(WWWDIR "/" opath ".json")
			printf "%s %s %s |%s\n", dir1, dir2, dir3, vendor >> FILE_FLAT
			close(FILE_FLAT)
			if (OPTION == "build_shellscript") {
				gsub(/'"'"'/, "&apos;", vendor)
				print dir1 dir2 dir3 ")e '\''" vendor "'\'' dq ;;" >> SHELLFILE
				close(SHELLFILE)
			}
			ALL++; NEW++
			vendor=""; addr1=""; addr2=""; country=""
		}
		next
	}
	END {
		print "ALL=" ALL > STATS
		print "NEW=" NEW > STATS
	}
	' "$FILE" 2>/dev/null

	# shellcheck disable=SC1090
	. "$STATS"

	if [ "$OPTION" = "build_shellscript" ]; then
		echo 'esac' >> "$SHELLFILE"
		log "[OK] new script '$SHELLFILE'"
	fi

	if [ -n "$NEW" ] && [ "$NEW" -gt 0 ]; then
		log "new entries: $NEW overall: $ALL"

		sort -o "$FILE_FLAT" "$FILE_FLAT"

		[ -d '.git' ] && {
			git add 'oui.txt'
			git commit --author="bot <bot@intercity-vpn.de>" -m "oui.txt: adding $NEW entries, overall now: $ALL vendors"
			git gc
		}

		tar -C "$WWWDIR" -cf 'oui.tar' --exclude='oui.tar.xz' .
		xz -e 'oui.tar' && rm -f 'oui.tar'
		mv 'oui.tar.xz' "$WWWDIR"
	else
		log "no new entries - overall: $ALL"
	fi

	log "see: '$FILE_FLAT' and '$WWWDIR/oui.tar.xz'"
else
	rm -f "$FILE"
	false
fi
