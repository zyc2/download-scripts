#!/usr/bin/env bash
pb=$1
if [ -z "$pb" ]; then
  read -p "粘贴地址: " pb
fi
referer=$pb
page_id=${pb##*/}
echo "page_id= $page_id"
url="https://www.77file.com/down/${page_id}.html"
cmd="curl -s -k $url -H 'referer: $referer'"
echo "开始获取文件id=> $cmd"
html=$(eval "$cmd")
file_id=$(grep -P -o "(?<=load_down_addr1\(').+(?='\))" <<<"$html")
echo "file_id= $file_id"
cmd="curl -s -k -i 'https://www.77file.com/ajax.php' --data-raw 'action=load_down_addr1&file_id=$file_id'"
echo "开始获取下载地址=> $cmd"
address=$(eval "$cmd")
url=$(grep -P -o '(?<=a href=")http.+?(?=")' <<< "$address")
cookie=$(grep -P -o "freedownip=.+?;" <<< "$address")
echo "url= $url"
echo "cookie= $cookie"
file=${2}.rar
if [ -z "$2" ]; then
  file=${url##*/}
fi
cmd="curl -k $url -H 'cookie: $cookie' -o '$file'"
echo "开始下载=> $cmd"
eval "$cmd"