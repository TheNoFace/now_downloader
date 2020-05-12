#!/bin/bash

# TODO:
# 0) 스크립트 정상 종료 안되는 원인 찾기
# 1) wget로 playlist.m3u8을 받아 올 수 없으면 sleep 후 재시도
# 2) 스트리밍 중단 시 스크립트 재시작
# 3) 오전 스트리밍 구분 추가
# 4) 날이 하루 이상 차이날 경우 12시간 타이머
# 5) Video 스트림이 있을 경우 동시 다운로드

if [ $# -ne 1 ]
then
	echo "Usage: now ShowID"
	exit -1
else
	echo -e '\nShowID: '"$1"'\n'
	number="$1"
fi

opath=/srv/mount/ssd0/now
date=$(date +'%y%m%d')
# TODO 5)
vcheck=$(cat "$opath"/content/"$date"_"$number".content | grep -oP 'video":\K[^,]+')

function getstream()
{
	#exrefresh
	timer=3
	counter
	echo
	#wget -O "$opath"/content/"$date"_"$number".content https://now.naver.com/api/nnow/v1/stream/"$number"/content
	#exrefresh
	echo '방송시간: '"$starttime"' / 현재: '"$hour"':'"$min"':'"$sec"
	# TODO 5)
	if [ $vcheck = 'true' ]
	then
		echo -e '\n'"$title"' E'"$ep"' '"${subject//'\r\n'/}"
		echo -e 'Audio: '"$url"'\nVideo: '"$vurl"'\n'
		echo -e '오디오 파일: '"${filename//'/'/.}"'.ts\n비디오 파일: '"${filename//'/'/.}"'_video.ts\n'
		youtube-dl "$url" --output "$opath"/"${filename//'/'/.}".ts &
		youtube-dl "$vurl" --output "$opath"/"${filename//'/'/.}"_video.ts
	else
		echo -e '\n'"$title"' E'"$ep"' '"${subject//'\r\n'/}"'\n'"$url"'\n\n파일 이름: '"${filename//'/'/.}"'.ts\n'
		youtube-dl "$url" --output "$opath"/"${filename//'/'/.}".ts
	fi
	codec=$(ffprobe -v error -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$opath"/"${filename//'/'/.}".ts)
	if [ $codec = mp3 ]
	then 
		echo -e '\nCodec: MP3, Saving into mp3 file\n'
		ffmpeg -i "$opath"/"${filename//'/'/.}".ts -vn -c:a copy "$opath"/"${filename//'/'/.}".mp3
		echo -e '\nConverting Complete ('"${filename//'/'/.}"'.mp3)\n'
	elif [ $codec = aac ]
	then
		echo -e '\nCodec: AAC, Saving into m4a file\n'
		ffmpeg -i "$opath"/"${filename//'/'/.}".ts -vn -c:a copy "$opath"/"${filename//'/'/.}".m4a
		echo -e '\nConverting Complete ('"${filename//'/'/.}"'.m4a)\n'
	else
		echo -e '\nERROR: : Unable to get codec info\n'
		exit -1
	fi
}

function exrefresh()
{
	title=$(cat "$opath"/content/"$date"_"$number".content | grep -oP '"home":{"title":{"text":"\K[^"]+')
	url=$(cat "$opath"/content/"$date"_"$number".content | grep -oP 'streamUrl":"\K[^"]+')
	# TODO 5)
	if [ $vcheck = 'true' ]
	then
		vurl=$(cat "$opath"/content/"$date"_"$number".content | grep -oP 'videoStreamUrl":"\K[^"]+')
	fi
	startdate=$(cat "$opath"/content/"$date"_"$number".content | grep -oP 'start":"20\K[^T]+')
	starttime=$(cat "$opath"/content/"$date"_"$number".content | grep -oP 'start":"\K[^"]+' | grep -oP 'T\K[^.+]+')
	subject=$(cat "$opath"/content/"$date"_"$number".content | grep -oP '},"title":{"text":"\K[^"]+')
	ep=$(cat "$opath"/content/"$date"_"$number".content | grep -oP '"count":"\K[^회"]+')
	filename="$date"."NAVER NOW"."$title".E"$ep"."${subject//'\r\n'/}"_"$hour$min$sec"
}

function timeupdate()
{
	hour=$(date +'%H')
	min=$(date +'%M')
	sec=$(date +'%S')
	stimehr=$(expr substr "${starttime//':'/}" 1 2)
	stimemin=$(expr substr "${starttime//':'/}" 3 2)
	hourcheck=$(expr "$stimehr" - "$hour")
	mincheck=$(expr "$stimemin" - "$min")
	if [ $mincheck -le 0 ]
	then
		timecheck=$(echo "$hourcheck*60" | bc -l)
	elif [ $mincheck -gt 0 ]
	then
		timecheck=$(echo "$hourcheck*60+$mincheck" | bc -l)
	else
		echo -e '\ntimeupdate(): ERROR\n'
	fi
}

function counter()
{
	echo
	while [ $timer -gt 0 ]
	do
		echo -ne 'sleeping for '"$timer\033[0K"'s'"\r"
		sleep 1
		: $((timer--))
	done
	echo
}

function diffdatesleep()
{
	while :
	do
		echo -e '방송일이 아닙니다\n'
		timeupdate	
		echo 'Hour difference: '"$hourcheck"
		echo 'Min difference: '"$mincheck"
		echo -e 'Time difference: '"$timecheck"' min'
		counter
		echo -e 'content 다시 불러오는 중...\n'
		wget -O "$opath"/content/"$date"_"$number".content https://now.naver.com/api/nnow/v1/stream/"$number"/content
		timeupdate
		exrefresh
		echo -e '방송일  : '"${startdate//'-'/}"' / 오늘: '"$date"
		echo '방송시간: '"${starttime//':'/}"' / 현재: '"$hour$min$sec"
		if [ $vcheck = 'true' ]
		then
			echo -e '\n'"$title"' E'"$ep"' '"${subject//'\r\n'/}"
			echo -e 'Audio: '"$url"'\nVideo: '"$vurl"'\n'
		else
			echo -e '\n'"$title"' E'"$ep"' '"${subject//'\r\n'/}"'\n'"$url"
		fi
		echo
		# 시작 시간이 65분 이상 차이
		if [ $hourcheck -ge 0 ] && [ $timecheck -ge 65 ]
		then
			timer=3600
		# 시작 시간이 65분 미만 차이
		elif [ $hourcheck -ge 0 ] && [ $timecheck -lt 65 ]
		then
			# 시작 시간이 10분 초과 차이
			if [ $hourcheck -ge 0 ] && [ $timecheck -gt 10 ]
			then
				timer=600
			# 시작 시간이 10분 이하 차이
			elif [ $hourcheck -ge 0 ] && [ $timecheck -le 10 ]
			then
				# 시작 시간이 2분 초과 차이
				if [ $hourcheck -ge 0 ] && [ $timecheck -gt 2 ]
				then
					timer=60
				# 시작 시간이 2분 이하 차이
				elif [ $hourcheck -ge 0 ] && [ $timecheck -le 2 ]
				then
					timer=1
				else
					echo -e '\nERROR: 1\n'
					exit -1
				fi
			else
				echo -e '\nERROR: 2\n'
				exit -1
			fi
		else
			echo -e '\nERROR: 3\n'
			exit -1
		fi
		# 시작일 확인
		if [ "$date" = "${startdate//'-'/}" ]
		then
			echo '방송일  : '"${startdate//'-'/}"' / 오늘: '"$date"
			echo '방송시간: '"${starttime//':'/}"' / 현재: '"$hour$min$sec"
			echo -e '\ncontent 불러오기 완료'
			exrefresh
			break
		fi
	done
}

wget -O "$opath"/content/"$date"_"$number".content https://now.naver.com/api/nnow/v1/stream/"$number"/content
exrefresh
timeupdate
# TODO 5)
vcheck=$(cat "$opath"/content/"$date"_"$number".content | grep -oP 'video":\K[^,]+')

# TODO 5)
if [ $vcheck = 'true' ]
then
	echo -e '비디오 스트림 발견, 함께 다운로드 합니다\n'
else
	echo -e '비디오 스트림 없음, 오디오만 다운로드 합니다\n'
fi

echo '방송일  : '"${startdate//'-'/}"' / 오늘: '"$date"
echo '방송시간: '"${starttime//':'/}"' / 현재: '"$hour$min$sec"

# 시작일이 다를 경우
if [ "$date" != "${startdate//'-'/}" ]
then
	timer=0
	diffdatesleep
	timeupdate
	# TODO 4)
	# 시작 시간이 됐을 경우
	if [ "$hour$min$sec" -ge "${starttime//':'/}" ]
	then
		echo -e '\n쇼가 시작됨\n'
		getstream
		echo -e '\nJob Finished, Code: 1\n'
	# 시작 시간이 안됐을 경우
	elif [ "$hour$min$sec" -lt "${starttime//':'/}" ]
	then
		echo -e '\n쇼가 아직 시작되지 않음'
		while :
		do
			echo '방송시간: '"${starttime//':'/}"' / 현재: '"$hour$min$sec"
			echo -e '\n대기 중...('"$hour$min$sec"')'
			sleep 1
			timeupdate			
			exrefresh
			# 시작 시간 확인
			if [ "$hour$min$sec" -ge "${starttime//':'/}" ]
			then
				echo '방송시간: '"${starttime//':'/}"' / 현재: '"$hour$min$sec"
				echo -e '쇼가 시작됨\n'
				break
			fi
		done
		getstream
		echo -e '\nJob Finished, Code: 2\n'
	else
		echo -e '\nERROR: 4\n'
		exit -1
	fi
# 시작일이 같을 경우
elif [ "$date" = "${startdate//'-'/}" ]
then
	echo -e '\n방송일입니다'
	if [ $vcheck = 'true' ]
	then
		echo -e '\n'"$title"' E'"$ep"' '"${subject//'\r\n'/}"
		echo -e 'Audio: '"$url"'\nVideo: '"$vurl"'\n'
	else
		echo -e '\n'"$title"' E'"$ep"' '"${subject//'\r\n'/}"'\n'"$url"
	fi
	timeupdate
	exrefresh
	echo 'Hour difference: '"$hourcheck"
	echo 'Min difference: '"$mincheck"
	echo -e 'Time difference: '"$timecheck"' min\n'
	# 시작 시간이 됐을 경우
	if [ "$hour$min$sec" -ge "${starttime//':'/}" ]
	then
		# 오전 방송일 경우
		# TODO 3)
		#if [ "${starttime//':'/}" -lt 120000 ] && [ "$hour$min$sec" -ge 120000 ]
		#then
		#	echo -e '\n오전 방송입니다\n'
			#현재 시각에서 00시 까지 남은 시간 계산해서 counter 설정 후 00시 넘길 수 있게
			#timehr=$(expr substr "$hour$min$sec" 1 2)
			#timer1=$(expr "$timehr" - "$stimehr")
			#timer=$("$timer1" - 1 * 60 * 60)
			#counter
		#fi
		echo -e '\n쇼가 시작됨\n'
		getstream
		echo -e '\nJob Finished, Code: 3\n'
	# 시작 시간이 안됐을 경우
	elif [ "$hour$min$sec" -lt "${starttime//':'/}" ]
	then
		echo -e '\n쇼가 아직 시작되지 않음'
		while :
		do
			echo '방송시간: '"${starttime//':'/}"' / 현재: '"$hour$min$sec"
			echo -e '\n대기 중...('"$hour$min$sec"')'
			sleep 1
			timeupdate			
			exrefresh
			# 시작 시간 확인
			if [ "$hour$min$sec" -ge "${starttime//':'/}" ]
			then
				echo '방송시간: '"${starttime//':'/}"' / 현재: '"$hour$min$sec"
				echo -e '\n쇼가 시작됨\n'
				break
			fi
		done
		getstream
		echo -e '\nJob Finished, Code: 2\n'
	else
		echo -e '\nERROR: 4\n'
		exit -1
	fi
else
	echo -e '\nERROR: 6\n'
	exit -1
fi