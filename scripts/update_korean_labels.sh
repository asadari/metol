#!/bin/sh
# Translate only unchanged upstream labels; preserve custom labels and values.
set -eu
SRC=${1:-/mnt/mmc/filmlab/recipes.json}
[ -f "$SRC" ] || exit 0
TMP="$SRC.ko.tmp"
trap 'rm -f "$TMP"' EXIT HUP INT TERM
sed \
  -e 's/\("label"[[:space:]]*:[[:space:]]*\)"EK Cyan 冷调"/\1"EK Cyan 쿨톤"/g' \
  -e 's/\("label"[[:space:]]*:[[:space:]]*\)"TriX 400 暖调"/\1"TriX 400 웜톤"/g' \
  -e 's/\("label"[[:space:]]*:[[:space:]]*\)"HP5 粗颗粒"/\1"HP5 거친 입자"/g' \
  -e 's/\("label"[[:space:]]*:[[:space:]]*\)"Delta 3200 粗犷"/\1"Delta 3200 거친 질감"/g' \
  -e 's/\("label"[[:space:]]*:[[:space:]]*\)"暖调 棕褐"/\1"웜톤 세피아"/g' \
  -e 's/\("label"[[:space:]]*:[[:space:]]*\)"冷调 青蓝"/\1"쿨톤 청색"/g' \
  -e 's/\("label"[[:space:]]*:[[:space:]]*\)"X-Pro 交叉"/\1"X-Pro 크로스"/g' \
  -e 's/\("label"[[:space:]]*:[[:space:]]*\)"Acros 冷调"/\1"Acros 쿨톤"/g' \
  -e 's/\("label"[[:space:]]*:[[:space:]]*\)"Velvia 50 风光"/\1"Velvia 50 풍경"/g' \
  -e 's/\("label"[[:space:]]*:[[:space:]]*\)"T-MAX 100 锐利"/\1"T-MAX 100 선명"/g' \
  -e 's/\("label"[[:space:]]*:[[:space:]]*\)"Pan F 极细"/\1"Pan F 미세 입자"/g' \
  -e 's/\("label"[[:space:]]*:[[:space:]]*\)"青橙"/\1"틸 오렌지"/g' \
  -e 's/\("label"[[:space:]]*:[[:space:]]*\)"暖旧"/\1"따뜻한 빈티지"/g' \
  -e 's/\("label"[[:space:]]*:[[:space:]]*\)"冷峻"/\1"차가운 톤"/g' \
  -e 's/\("label"[[:space:]]*:[[:space:]]*\)"褪色"/\1"페이드"/g' \
  -e 's/\("label"[[:space:]]*:[[:space:]]*\)"高调"/\1"하이키"/g' \
  -e 's/\("label"[[:space:]]*:[[:space:]]*\)"低调"/\1"로우키"/g' \
  -e 's/\("label"[[:space:]]*:[[:space:]]*\)"棕褐"/\1"세피아"/g' \
  -e 's/\("label"[[:space:]]*:[[:space:]]*\)"漂白"/\1"블리치"/g' \
  -e 's/\("label"[[:space:]]*:[[:space:]]*\)"蓝调时刻"/\1"블루아워"/g' \
  -e 's/\("label"[[:space:]]*:[[:space:]]*\)"Portra 800 推1600"/\1"Portra 800 1600 증감"/g' \
  "$SRC" > "$TMP"
if ! cmp -s "$SRC" "$TMP"; then
  [ -f "$SRC.before-ko" ] || cp -p "$SRC" "$SRC.before-ko"
  mv -f "$TMP" "$SRC"
fi
