#!/bin/bash
FILE="/sdcard/mod/cCheckbox.sh"
#
if [ ! -f "$FILE" ]; then
    /opt/usr/nx-ks/popup_timeout "cCheckbox 없음" 2
    /opt/usr/nx-ks/popup_timeout "먼저 생성하세요: $FILE " 3
	rm /opt/usr/nx-ks/auto/cCheckbox.sh
else
	$("$FILE")&
fi
