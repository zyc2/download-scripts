#!/usr/bin/env bash
pb=$1
if [ -z "$pb" ]; then
  read -p "粘贴地址: " pb
fi
referer=$pb
if [[ "$referer" == *.html ]]; then
  redirect=$(curl -s -k -i "$referer"|grep -P -o 'location: [/\w]+')
  referer=$(cut -d'/' -f1,2,3 <<< "$referer")${redirect##*: }
  referer=${referer%$'\n'}
fi
page_id=${referer##*/}
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
#cmd="curl -k $url -H 'cookie: $cookie' -o '$file'"
cmd="aria2c --header='cookie: $cookie' -c --check-certificate=false --retry-wait=3 --max-tries=50 --max-connection-per-server=3  '$url' -o '$file'"
echo "开始下载=> $cmd"
eval "$cmd"
