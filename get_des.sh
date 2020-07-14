#!/bin/bash

SHOW_ID=$1
today=$(date +%y%m%d)
OPATH=$(cat .opath)
content="${OPATH}/content/${today}_${SHOW_ID}.content"
wget -O "$content" "https://now.naver.com/api/nnow/v1/stream/${SHOW_ID}/content"

function renamer()
{
	str=$1
	str=${str//'"'/''}
	str=${str//'\r\n'/' '}
	str=${str//'\'/''}
	export $2="$str"
}

subject=$(jq '.contentList[].title.text' $content)
des=$(jq '.contentList[].description.text' $content)
url=$(jq '.contentList[].streamUrl' $content)

echo -e $des

: '
echo
echo "Before: $subject"
renamer "$subject" subject
echo "After: $subject"
echo
echo "Before: $des"
renamer "$des" des
echo "After: $des"
echo
echo "Before: $url"
renamer "$url" url
echo "After: $url"
'
