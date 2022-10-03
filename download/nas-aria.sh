pb=$1
if [ -z "$pb" ]; then
  read -p "粘贴地址: " pb
fi
ss=$(date +%s)
url=$pb
name=$2
if [ -n "$name" ]; then
  out=',{"out":"'$name'"}'
fi
json='{"jsonrpc":"2.0","id":"'$ss'","method":"aria2.addUri","params":["token:yvnenvy",["'$url'"]'$out']}'
echo $json|jq && \
curl --noproxy '*' http://nas:6881/jsonrpc -d"$json" -i
