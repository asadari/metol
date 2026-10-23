#!/bin/bash
FILE="/sdcard/mod/cButton.sh"
#
if [ ! -f "$FILE" ]; then
    /opt/usr/nx-ks/popup_timeout "cButton 없음" 2
    /opt/usr/nx-ks/popup_timeout "먼저 생성하세요: $FILE " 3
else
	$("$FILE")&
fi
