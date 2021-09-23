#!/bin/sh

# cron-mode:
# while :; do rm -f ui.txt && ./update.sh /dev/shm/oui; git push; date; sleep 9999; done
#
# - this script downloads 'oui.txt' from URL
# - parse and write out for each OUI-entry a textfile to:
#   - WWWDIR/byte1/byte2/byte3 so that
#   - e.g. http://server/oui/3c/d9/2b       is a textfile with vendor name + address
#   - e.g. http://server/oui/3c/d9/2b.json  is a textfile with the same in json-notation

WWWDIR="${1:-/var/www/oui}"	# for testing use e.g. /dev/shm/oui
FILE="${2:-oui.txt}"		# if file already exists, it is not downloaded
OPTION="$3"			# e.g. <empty> or 'build_shellscript' (experimental -> ~810k)
OPTION_ARG="${4:-oui.sh}"	# in shellscript-mode: scriptname

URL='http://standards.ieee.org/develop/regauth/oui/oui.txt'
NEW=0
ALL=0
FILE_FLAT="$FILE.flatdb.txt"
CARRIAGE_RETURN="$( printf '\r' )"

alias explode='set -f;set +f --'
log() { >&2 printf '%s | %s\n' "$(date)" "$1"; }
e() { printf '%s\n' "$1"; }
char_tolowercase() { case "$1" in A) C=a ;; B) C=b ;; C) C=c ;; D) C=d ;; E) C=e ;; F) C=f ;; esac; }

if test -f "$FILE" || wget --no-check-certificate -O "$FILE" "$URL"; then
	# a typical block looks like:
	#
	# 3C-D9-2B   (hex)                Hewlett Packard
	# 3CD92B     (base 16)            Hewlett Packard
	#                                 11445 Compaq Center Drive
	#                                 Houston    77070
	#                                 US
	#
	# (next entry ...)

	case "$OPTION" in
		'build_shellscript')
			SHELLFILE="$OPTION_ARG"
			log "[OK] new script '$SHELLFILE'"
			{
				e '#!/bin/sh'
				e 'e(){ printf "%s\n" "$*";}'
				e
				e "case \"\$1\" in"
			} >"$SHELLFILE" && chmod +x "$SHELLFILE"

			shellsafe()
			{
				e "$1" | sed -e "s/'/'\\\''/g" -e 's/[^a-zA-Z0-9\._~}{(), =+?@\\/:-\[\]]//g'
			}
		;;
	esac

	# start a new write:
	true >"$FILE_FLAT"

	# only parse, when content has changed:
	test -f "$FILE_FLAT.hash"       && read -r HASH_OLD <"$FILE_FLAT.hash"
	HASH_NEW="$( md5sum <"$FILE" )" && e    "$HASH_NEW" >"$FILE_FLAT.hash"
	test "$HASH_OLD" = "$HASH_NEW"  && log "[OK] no changes in '$FILE'" && exit 0

	log "[OK] parsing '$FILE' with $( wc -l <"$FILE" ) lines, this needs some time..."
	while read -r LINE; do
		# shellcheck disable=SC2086
		explode $LINE

		case "$1 $2 $3" in
			[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]' (base 16)')
				ALL=$(( ALL + 1 ))

				# speedcode without forks and with builtins only:
				MAC=$1
				MACLOWER=

				for _ in 1 2 3 4 5 6; do {
					C="${MAC%${MAC#?}}"		# get first char
					MAC="${MAC#?}"			# remove first char
					char_tolowercase "$C"
					MACLOWER="${MACLOWER}${C}"	# append
				} done

				# MAC is e.g. "ab34ef (base 16)"
				MAC="$MACLOWER"
				DIR1="${MAC%${MAC#??}}"		# ab34ef... -> ab
				MAC="${MAC#??}"			# remove first 2 chars
				DIR2="${MAC%${MAC#??}}"		# 34ef...   -> 34
				MAC="${MAC#??}"			# remove first 2 chars
				DIR3="${MAC%${MAC#??}}"		# ef...     -> ef

				OUTFILE="$WWWDIR/$DIR1/$DIR2/$DIR3"		# e.g. oui/ab/34/ef
				shift 3 || log "[ERR] shift: ALL: $ALL LINE: '$LINE'"

				# TODO: speedup
				ORGANIZATION="$( e "$*" | sed "s/${CARRIAGE_RETURN}\$//" )"

				case "$OPTION" in
					'build_shellscript')
						# TODO: try to group e.g. all 450 entries with 'Samsung Electronics'
						# here we output a good parsable/sortable file for later building shell/json structures:
						e >>"$FILE_FLAT" "$DIR1 $DIR2 $DIR3 |$ORGANIZATION"
						e >>"$SHELLFILE" "${DIR1}${DIR2}${DIR3})e '$( shellsafe "$ORGANIZATION" )';;"
					;;
				esac

				if [ -f "$OUTFILE" ]; then
					ORGANIZATION=			# no need for writing again
				else
					NEW=$(( NEW + 1 ))
					mkdir -p "$WWWDIR/$DIR1/$DIR2"

					e >"$OUTFILE" "$ORGANIZATION"

					VENDOR_NAME="$(    sed '1q;d' "$OUTFILE" )"
					VENDOR_STREET="$(  sed '2q;d' "$OUTFILE" )"
					VENDOR_CITY="$(    sed '3q;d' "$OUTFILE" )"
					VENDOR_COUNTRY="$( sed '4q;d' "$OUTFILE" )"

					{
						# TODO: like https://macaddress.io/database-download
						# https://stackoverflow.com/questions/5543490/json-naming-convention
						e '{'
						e "  \"vendorOUI\": \"$DIR1-$DIR2-$DIR3\","
						e "  \"vendorOUIbyte1\": \"$DIR1\","
						e "  \"vendorOUIbyte2\": \"$DIR2\","
						e "  \"vendorOUIbyte3\": \"$DIR3\","
						e "  \"vendorName\": \"$VENDOR_NAME\","
						e "  \"vendorStreet\": \"$VENDOR_STREET\","
						e "  \"vendorCity\": \"$VENDOR_CITY\","
						e "  \"vendorCountry\": \"$VENDOR_COUNTRY\""
						e '}'
					} >"$OUTFILE.json"
				fi
			;;
			*[a-zA-Z0-9]*)
				# likely the countrycode:
				case "$ORGANIZATION" in
					'') ;;
					 *) e "$*" | sed "s/${CARRIAGE_RETURN}\$//" >>"$OUTFILE" ;;
				esac
			;;
			*)
				ORGANIZATION=		# abort parsing, wait for next entry
			;;
		esac
	done <"$FILE"

	case "$OPTION" in
		'build_shellscript') e >>"$SHELLFILE" 'esac' ;;
	esac

	sort "$FILE_FLAT" >"$FILE_FLAT.sorted"
	mv "$FILE_FLAT.sorted" "$FILE_FLAT"

	if [ $NEW -gt 0 ]; then
		log "new entries: $NEW overall: $ALL"
		[ -d '.git' ] && {
			git add 'oui.txt'
			git commit --author="bot <bot@intercity-vpn.de>" -m "oui.txt: adding $NEW entries, overall now: $ALL vendors"
			git gc
		}

		tar -C "$WWWDIR" -cf 'oui.tar' --exclude='oui.tar.xz' .
		xz -e 'oui.tar' && rm -f 'oui.tar'
		mv 'oui.tar.xz' "$WWWDIR"	# ~ 1600 kilobytes
	else
		log "no new entries - overall: $ALL"
	fi

	log "see: '$FILE_FLAT' and '$WWWDIR/oui.tar.xz'"
else
	rm -f "$FILE"
	false
fi
