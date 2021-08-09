#!/usr/bin/env bash

read -p "粘贴地址: " pb
ss=$(date +%s)

echo '开始抓取页面信息:'
html=$(curl -s -k "$pb")
name=$(grep '"og:title"' <<<"$html" | grep -P -o '(?<=content=")[^"]+').ts
#m3u8=$(grep '"preload"' <<<"$html" | grep -P -o '(?<=href=")[^"]+')
m3u8=$(grep -P -o 'http\S+?m3u8' <<<"$html")
dir=$(echo "$m3u8" | grep -P -o '\d+.m3u8')
mkdir -p "$dir"
m3="$dir/$dir"
echo "保存文件名=>$name"
echo '开始抓取视频列表:'
curl -s -k "$m3u8" >"$m3"

THREAD=1
echo "开始下载视频=线程数=>$THREAD,线程过多服务器会限制导致抓取失败！！"
FIFO=$$.fifo
mkfifo $FIFO
exec 5<>${FIFO} #创建文件标示符
rm -rf ${FIFO}
for ((i = 1; i <= THREAD; i++)); do
  echo "" #初始化线程数
done >&5
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

files=$(grep -P -o '^[^#]+ts' "$m3")
max=$(wc -l <<<"$files")
i=0
for f in $files; do
  read -u5
  i=$((i + 1))
  {
    bn=$(date +%s%N)
    curl -s -k "$(sed -r "s/$dir/$f/" <<<"$m3u8")" >"$dir/$f"
    un=$(($(date +%s%N) - bn))
    rn=$(((max - i) * un / THREAD))
    bc=$(wc -c <"$dir/$f")
    bs=$((bc * 1000000000 / un))
    fraction="$i/$max($(numfmt --to=iec <<<$bc))"
    rate="$((100 * i / max))%"
    speed="$(numfmt --to=iec <<<$bs)/s *${THREAD}"
    use_time="$(displaytime $(($(date +%s) - ss)))"
    remain="$(displaytime $((rn / 1000000000)))"
    printf "  %-20s%-5s%-12s已用时:%-15s剩余估算:%-15s\r" "$fraction" "$rate" "$speed" "$use_time" "$remain"
    echo "" >&5 #任务执行完后在fd5中写入一个占位符
  } &
done

wait
exec 5>&- #关闭fd5的管道
echo

decrypt=$(grep '#EXT-X-KEY' "$m3")
key_url=$(grep -P -o '(?<=URI\=")[^"]+' <<<"$decrypt")
vector=$(grep -P -o '(?<=IV\=0x)\w+' <<<"$decrypt")
method=$(grep -P -o '(?<=METHOD\=)[^,]+' <<<"$decrypt")

if [ -n "$decrypt" ]; then
  echo '文件有加密有加密'
  echo "$decrypt"
  if [ "$method" = 'AES-128' ]; then
    echo 'AES-128加密！！！'
    echo 'initialisation vector:'
    echo "$vector"
    echo "下载key:$key_url"
    key="$(curl -s -k "$(sed -r "s/$dir/$key_url/" <<<"$m3u8")" | xxd -plain)"
    echo "$key"
    echo '开始解密+合并:'
    i=0
    for f in $files; do
      openssl aes-128-cbc -d -in "$dir/$f" -out "$f" -nosalt -iv "$vector" -K "$key"
      cat "$f" >>"$name"
      rm "$f" "$dir/$f"
      i=$((i + 1))
      echo -en "$i/$max($((100 * i / max))%)\r"
    done
    echo
  else
    echo '不支持的加密方法'
    echo "$method"
    exit 1
  fi
else
  echo '文件有加密没有加密:开始合成'
  for f in $files; do
    cat "$dir/$f" >>"$name"
    rm "$dir/$f"
  done
fi
echo '文件合成完毕:'
rm -r "$dir"
echo "总耗时:$(displaytime $(($(date +%s) - ss)))"
realpath "$name"
exit 0
