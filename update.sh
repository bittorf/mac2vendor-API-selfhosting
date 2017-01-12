#!/bin/sh

URL='http://standards.ieee.org/develop/regauth/oui/oui.txt'
WWWDIR="${1:-/var/www/oui}"	# for testing use e.g. /dev/shm/oui
FILE="${2:-oui.txt}"		# if file already exists, it is not downloaded
OPTION="$3"			# e.g. <empty> or 'build_shellscript' (experimental -> ~810k)
OPTION_ARG="${4:-oui.sh}"
NEW=0
ALL=0
CR="$( printf '\r' )"

if test -e "$FILE" || wget -O "$FILE" "$URL"; then
	# 3C-D9-2B   (hex)                Hewlett Packard
	# 3CD92B     (base 16)            Hewlett Packard
	#                                 11445 Compaq Center Drive
	#                                 Houston    77070
	#                                 US
	#
	# (next entry ...)
	case "$OPTION" in
		'build_shellscript')
			logger -s "[OK] new script '$OPTION_ARG'"
			{
				echo '#!/bin/sh'
				echo 'e(){ echo $*;}'
				echo
				echo "case \"\$1\" in"
			} >"$OPTION_ARG" && chmod +x "$OPTION_ARG"
		;;
	esac

	logger -s "[OK] parsing '$FILE' with $( wc -l <"$FILE" ) lines"
	while read -r LINE; do
		# shellcheck disable=SC2086
		set -- $LINE

		case "$1" in
			[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F])
				ALL=$(( ALL + 1 ))
				mac="$( echo "$1" | sed 'y/ABCDEF/abcdef/' )"	# lowercase

				DIR1="$( echo "$mac" | cut -b 1,2 )"
				DIR2="$( echo "$mac" | cut -b 3,4 )"
				DIR3="$( echo "$mac" | cut -b 5,6 )"
				OUTFILE="$WWWDIR/$DIR1/$DIR2/$DIR3"	# e.g. 3CD92B -> oui/3c/d9/2b
				shift 3 || logger -s "[ERR] shift: ALL: $ALL LINE: '$LINE'"
				ORGANIZATION="$( echo "$*" | sed "s/${CR}\$//" )"

				case "$OPTION" in
					'build_shellscript')
						# TODO: try to group e.g. all 450 entries with 'Samsung Electronics'
						SHELLSAFE="$( echo "$ORGANIZATION" | sed -e "s/'/'\\\''/g" \
											 -e 's/[^a-zA-Z0-9\._~}{(), =+?@\\/:-\[\]]//g' )"
						echo >>"$OPTION_ARG" "${DIR1}${DIR2}${DIR3})e '$SHELLSAFE';;"
					;;
				esac

				if [ -e "$OUTFILE" ]; then
					ORGANIZATION=			# no need for writing again
				else
					NEW=$(( NEW + 1 ))
					mkdir -p "$WWWDIR/$DIR1/$DIR2"

					echo >"$OUTFILE" "$ORGANIZATION"
				fi
			;;
			*[a-z0-9]*)
				test "$ORGANIZATION" && echo "$*" | sed "s/${CR}\$//" >>"$OUTFILE"
			;;
			*)
				ORGANIZATION=		# abort parsing, wait for next entry
			;;
		esac
	done <"$FILE"

	[ "$OPTION" = 'build_shellscript' ] && echo >>"$OPTION_ARG" 'esac'

	if [ $NEW -gt 0 ]; then
		logger -s "new entries: $NEW overall: $ALL"
		[ -d '.git' ] && {
			git add 'oui.txt'
			git commit -m "oui.txt: adding $NEW new entries, overall now: $ALL"
		}

		tar -C "$WWWDIR" -cf 'oui.tar' --exclude='oui.tar.xz' .
		xz -e 'oui.tar'
		mv 'oui.tar.xz' "$WWWDIR"	# ~ 800 Kbytes
	else
		logger -s "no new entries - overall: $ALL"
	fi
else
	rm "$FILE"
	false
fi
