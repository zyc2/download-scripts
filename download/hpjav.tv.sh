#!/usr/bin/env bash
lkey='NzMzNDMxNzQyODJhNWU2MjYzNDM3ODc5NmU0Mzc4MzY2YTMzMmE1ODM1NjQzMTc5NmUyNg=='
pb=$1
if [ -z "$pb" ]; then
  read -p "粘贴地址: " pb
fi
ss=$(date +%s)
pb="http${pb#*http}"
echo '开始抓取页面信息:'
html=$(curl -s -k "${pb}")
name=$(grep -P -o '(?<=<title>).+(?=</title>)' <<<"$html")
name=${name/ - JAV Online HPJAV/}
echo "标题    -> $name"
vser=$(echo $html | grep -P -o '(?<=var vser=JSON.parse\(atob\(").+?(?=")' | base64 -d)
l0=$(echo $vser | grep -P -o '".+?"' | sed 's/"//g')
key=$(base64 -d <<<"$lkey" | sed 's/../\\x&/g;s/^/printf "/;s/$/"/' | bash | tr 'a-zA-Z' 'n-za-mN-ZA-M')
#echo "key: $key"
vl=()
for r in $l0; do
  url=$(./hpjav.xor.py $r $key)
  echo "观看地址: $url"
  vl+=("$url")
done
one=$(echo "$vl" | grep asianclub | head -n1)
echo -----------------
echo 选择地址: $one
info=$(sed 's/\/v\//\/api\/source\//g' <<<$one)
echo 请求信息: $info
json=$(curl -s -k $info -F'r=https://hpjav.tv/' -F'd=asianclub.tv')
echo "清晰度列表:"
jq .data[].label <<<$json
lab=$(jq .data[].label <<<$json | sort -V | tail -n1)
echo "选择清晰度: $lab"
url=$(jq ".data[]|first(select(.label==$lab)).file" <<<$json)
type=$(jq ".data[]|first(select(.label==$lab)).type" <<<$json)
echo "开始下载: $type $lab $url"
url=${url//\"/}
file="$name.${type//\"/}"
echo "文件名: $file"
#aria2c "$url" -o "$file"
echo "添加nas aria任务"
./nas-aria.sh "$url" "$file"
