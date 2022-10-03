#!/usr/bin/env bash
# shellcheck disable=SC2162
pb=$1
if [ -z "$pb" ]; then
  read -p "m3u8地址: " pb
fi
ss=$(date +%s)

name=$2
if [ -z "$name" ]; then
  name=$ss
fi
name="$name".ts

if [ -f "$name" ]; then
  echo "$name exists,exit!"
  exit 0
fi

m1="$pb"
m1="http${m1#*http}"
echo "索引地址-> $m1"
m2=$(curl -s -L -k "$m1"|grep -P -o '.+\.m3u8.*'|head -n1)
function full_url() {
    if [[ $1 == http* ]]; then
        echo "$1"
        return
    fi
    if [[ $1 == /* ]]; then
        echo "$(cut -d'/' -f1,2,3 <<< "$m1")$1"
        return
    fi
    echo "${m1%/*}/$1"
}
if [ -n "$m2" ]; then
  echo "二级索引-> $m2"
  if [[ $m2 != http* ]]; then
    m2=$(full_url "$m2")
    echo "二级索引-> $m2"
  fi
  m1=$m2
fi

dir=$ss
mkdir -p "$dir"
m3="$dir/$dir"

echo "临时目录-> $dir"
curl -s -L -k "$m1" > "$m3"
echo "索引文件-> $m3"
files=$(grep -P -o '^[^#]+\.ts.*' "$m3")

THREAD=3
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

max=$(wc -l <<<"$files")
echo "文件数  -> $max"

# files=$(grep -P -o '^[^#]+ts' "$m3")
# max=$(wc -l <<<"$files")
i=0
for f in $files; do
  read -u5
  i=$((i + 1))
  {
    bn=$(date +%s%N)
    url=$(full_url "$f")
    f=$(basename "$f")
    curl -s -L -k "$url" >"$dir/$f"
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
key_url=$(full_url "$key_url")
vector=$(grep -P -o '(?<=IV\=0x)\w+' <<<"$decrypt")
vector=${vector:-00000000000000000000000000000000} #If variable not set or null, use default.
method=$(grep -P -o '(?<=METHOD\=)[^,]+' <<<"$decrypt")

if [ -n "$decrypt" ]; then
  echo '文件有加密有加密'
  echo "$decrypt"
  if [ "$method" = 'AES-128' ]; then
    echo 'AES-128加密！！！'
    echo 'initialisation vector:'
    echo "$vector"
    echo "下载key:$key_url"
    key="$(curl -s -L -k "$key_url" | xxd -plain)"
    echo "$key"
    echo '开始解密+合并:'
    i=0
    for f in $files; do
      f=$(basename "$f")
      openssl aes-128-cbc -d -in "$dir/$f" -out "$f" -nosalt -iv "$vector" -K "$key"
      cat "$f" >> "$name"
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
  i=0
  for f in $files; do
    f=$(basename "$f")
    cat "$dir/$f" >>"$name"
    rm "$dir/$f"
    i=$((i + 1))
    echo -en "$i/$max($((100 * i / max))%)\r"
  done
  echo
fi
echo '文件合成完毕:'
rm -r "$dir"
echo "总耗时:$(displaytime $(($(date +%s) - ss)))"
realpath "$name"
exit 0


