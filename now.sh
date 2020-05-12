#!/bin/bash

# TODO:
# 0) 2020-05-12 해결 | 스크립트 정상 종료 안되는 원인 찾기
# 1) wget로 playlist.m3u8을 받아 올 수 없으면 sleep 후 재시도
# 2) 스트리밍 중단 시 스크립트 재시작
# 3) 오전 스트리밍 구분 추가
# 4) 날이 하루 이상 차이날 경우 12시간 타이머

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

function getstream()
{
	timer=5
	counter
	echo
	wget -O "$opath"/content/"$date"_"$number".content https://now.naver.com/api/nnow/v1/stream/"$number"/content
	exrefresh
	echo 방송시간: "$starttime" '/' 현재: "$hour":"$min":"$sec"
	echo -e '\n'"$title"' E'"$ep"' '"${subject//'\r\n'/}"'\n'"$url"'\n\n'파일 이름': '"${filename//'/'/.}".ts'\n'
	youtube-dl "$url" --output "$opath"/"${filename//'/'/.}".ts
	codec=$(ffprobe -v error -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$opath"/"${filename//'/'/.}".ts)
	if [ $codec = mp3 ]
	then 
		echo -e '\nCodec: MP3, Saving into mp3 file\n'
		ffmpeg -i "$opath"/"${filename//'/'/.}".ts -vn -c:a copy "$opath"/"${filename//'/'/.}".mp3
		echo -e '\n파일 이름: '"${filename//'/'/.}"'.mp3'
	elif [ $codec = aac ]
	then
		echo -e '\nCodec: AAC, Saving into m4a file\n'
		ffmpeg -i "$opath"/"${filename//'/'/.}".ts -vn -c:a copy "$opath"/"${filename//'/'/.}".m4a
		echo -e '\n파일 이름: '"${filename//'/'/.}"'.m4a'
	else
		echo -e '\nERROR: : Unable to get codec info\n'
		exit -1
	fi
}

function exrefresh()
{
	title=$(cat "$opath"/content/"$date"_"$number".content | grep -oP '"home":{"title":{"text":"\K[^"]+')
	url=$(cat "$opath"/content/"$date"_"$number".content | grep -oP 'streamUrl":"\K[^"]+')
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
	timecheck=$(echo "$hourcheck*60+$mincheck" | bc -l)
}

function counter()
{
	while [ $timer -gt 0 ]
	do
		echo -ne 'sleeping for '"$timer\033[0K"s"\r"
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
		echo 'Time difference: '"$timecheck"' min'
		counter
		echo -e '\ncontent 새로 고침 중...\n'
		wget -O "$opath"/content/"$date"_"$number".content https://now.naver.com/api/nnow/v1/stream/"$number"/content
		timeupdate
		exrefresh
		echo -e '방송일  : '"${startdate//'-'/}"' / 오늘: '"$date"
		echo '방송시간: '"${starttime//':'/}"' / 현재: '"$hour$min$sec"
		echo -e '\n'"$title"' E'"$ep"' '"${subject//'\r\n'/}"'\n'"$url"
		echo
		# 시작 시간이 70분 초과 차이
		if [ $hourcheck -ge 0 ] || [ $timecheck -gt 70 ]
		then
			timer=3600
		# 시작 시간이 70분 이하 차이
		elif [ $hourcheck -ge 0 ] || [ $timecheck -gt 70 ]
		then
			# 시작 시간이 10분 초과 차이
			if [ $hourcheck -ge 0 ] || [ $timecheck -gt 10 ]
			then
				timer=600
			# 시작 시간이 10분 이하 차이
			elif [ $hourcheck -ge 0 ] || [ $timecheck -le 10 ]
			then
				# 시작 시간이 2분 초과 차이
				if [ $hourcheck -ge 0 ] || [ $timecheck -gt 2 ]
				then
					timer=60
				# 시작 시간이 2분 이하 차이
				elif [ $hourcheck -ge 0 ] || [ $timecheck -le 2 ]
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
			echo -e '\ncontent 불러오기 완료'
			break
		fi
	done
}

wget -O "$opath"/content/"$date"_"$number".content https://now.naver.com/api/nnow/v1/stream/"$number"/content
exrefresh
timeupdate

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
		exrefresh
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
				echo -e '\n쇼가 시작됨\n'
				break
			fi
		done
		exrefresh
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
	echo -e '\n'"$title"' E'"$ep"' '"${subject//'\r\n'/}"'\n'"$url"'\n'
	timeupdate
	exrefresh
	echo 'Hour difference: '"$hourcheck"
	echo 'Min difference: '"$mincheck"
	echo 'Time difference: '"$timecheck"' min'
	# 시작 시간이 됐을 경우
	if [ "$hour$min$sec" -ge "${starttime//':'/}" ]
	then
		# 오전 방송일 경우
		# TODO 3)
		#if [ "${starttime//':'/}" -lt 120000 ] || [ "$hour$min$sec" -ge 120000 ]
		#then
		#	echo -e '\n오전 방송입니다\n'
			#현재 시각에서 00시 까지 남은 시간 계산해서 counter 설정 후 00시 넘길 수 있게
			#timehr=$(expr substr "$hour$min$sec" 1 2)
			#timer1=$(expr "$timehr" - "$stimehr")
			#timer=$("$timer1" - 1 * 60 * 60)
			#counter
		#fi
		echo -e '\n쇼가 시작됨\n'
		exrefresh
		getstream
		echo -e '\nJob Finished, Code: 3\n'
	# 시작 시간이 안됐을 경우
	elif [ "$hour$min$sec" -lt "${starttime//':'/}" ]
	then
		echo -e '\n쇼가 아직 시작되지 않음'
		while :
		do
			time=$(date +'%T')
			echo -e '\n대기 중...('"$hour$min$sec"')'
			sleep 1
			exrefresh
			# 시작 시간 확인
			if [ "$hour$min$sec" -ge "${starttime//':'/}" ]
			then
				echo '방송시간: '"${starttime//':'/}"' / 현재: '"$hour$min$sec"
				echo -e '\n쇼가 시작됨\n'
				break
			fi
		done
		exrefresh
		getstream
		echo -e '\nJob Finished, Code: 4\n'
	else
		echo -e '\nERROR: 5\n'
		exit -1
	fi
else
	echo -e '\nERROR: 6\n'
	exit -1
fi