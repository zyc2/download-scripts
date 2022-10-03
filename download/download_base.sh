#!/usr/bin/env bash
# shellcheck disable=SC2162
pb=$1
if [ -z "$pb" ]; then
  read -p "粘贴地址: " pb
fi
pb="http${pb#*http}"
echo '开始抓取页面信息:'
html=$(curl -s -k "${pb}")
if [ -z "$html" ]; then
  echo "页面抓取失败"
  exit 1
fi
title=$(grep -P -o '(?<=<title>).+(?=</title>)' <<< "$html")
echo "标题    -> $title"

host=$(cut -d'/' -f1,2,3 <<< "$pb")
function full_url() {
    if [[ $1 == http* ]]; then
        echo "$1"
        return
    fi
    if [[ $1 == /* ]]; then
        echo "$host$1"
        return
    fi
    echo "$host/$1"
}
function file_extension(){
  suffix=${url##*.}
  echo "."${suffix%\?*}
}
function displaytime() {
  local T=$1
  local D=$((T / 60 / 60 / 24))
  local H=$((T / 60 / 60 % 24))
  local M=$((T / 60 % 60))
  local S=$((T % 60))
  ((D > 0)) && printf '%3dd' $D
  ((H > 0)) && printf '%2dh:' $H
  ((M > 0)) && printf '%2dm:' $M
  printf '%2ds' $S
}
watch_last=$(date +%s%N)
watch_start=$watch_last
function stop_watch(){
  i=$1
  max=$2
  file=$3
  now=$(date +%s%N)
  use_time="$(displaytime $(((now - watch_start)/1000000000)))"
  rate="$((100 * i / max))% "
  remain="$(((max-i)*(now - watch_start)/i/1000000000))"
  remain="$(displaytime $remain)"
  bc=$(wc -c <"$file")
  un=$((now - watch_last))
  bs=$((bc * 1000000000 / un))
  speed="$(numfmt --to=iec <<<$bs)/s"
  fraction="$i/$max"
  file="$file($(numfmt --to=iec <<<$bc))"
  printf "  %-10s%-5s%-8s已用时:%-12s剩余估算:%-12s %-40s\r" "$fraction" "$rate" "$speed" "$use_time" "$remain" "$file"
  watch_last=$now
  if [ "$i" -eq "$max" ]; then
    echo ""
    #echo "下载耗时:$(displaytime $(((now - watch_start)/1000000000)))"
  fi
}
function zget() {
  wget "$1" --progress=bar:force 2>&1 | tail -f -n +8
}

