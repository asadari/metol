#!/bin/bash
renice -n -10 -p $$
tii=($(systemctl show-environment))
for i in "${tii[@]}"; do if [[ $i == "fps="* ]]; then cfps=${i:4}; fi; done
fps=$(/opt/usr/nx-ks/popup_entry "초점 이동 속도 [1~255]:" "속도 설정" 취소 $cfps number )
[[ $fps =~ ^[0-9]+$ ]] || fps=4
systemctl set-environment fps=$fps
sync;sync;sync
/opt/usr/nx-ks/br_up.sh