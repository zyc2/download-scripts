#!/usr/bin/env bash
source download_base.sh

imgs=$(echo $html|grep -P -o '<img src=.+?>'|grep -P -o '(?<=").+(?=")')

dir=${title% –*}
echo "创建目录 -> $dir"
mkdir -p "$dir"
cd "$dir"
i=0
max=$(wc -l <<<"$imgs")
for img in $imgs; do
  i=$((i + 1))
  url=$(full_url $img)
  name=$(printf "%04d" $i)$(file_extension $url)
  #echo "下载 $url -> $name"
  #wget "$url" -O "$name" --progress=bar:force 2>&1 | tail -f -n +8
  wget "$url" -O "$name" -q
  stop_watch $i $max "$name"
done
