#!/bin/bash

# TODO:
# 200513 해결 | 0) 스크립트 정상 종료 안되는 원인 찾기
# 200513 임시 | 1) wget로 playlist.m3u8을 받아 올 수 없으면 sleep 후 재시도
# 2) 스트리밍 중단 시 스크립트 재시작
# 3) 오전 스트리밍 구분 추가
# 4) 날이 하루 이상 차이날 경우 12시간 타이머

if [ $# -eq 2 ]
then
	if [ $1 = "-f" ]
	then
		if [ -z $2 ]
		then
			echo "Usage: now (-f) ShowID"
			echo "Use -f to force download"
			exit -1
		else
			echo -e '\nForce Download Enabled!'
			echo -e 'ShowID: '"$2"'\n'
			number="$2"
		fi
	else
		echo "Usage: now (-f) ShowID"
		echo "Use -f to force download"
		exit -1
	fi
elif [ $# -ne 1 ]
then
	echo "Usage: now (-f) ShowID"
	echo "Use -f to force download"
	exit -1
elif [ $1 = "-f" ]
then
	echo "Usage: now (-f) ShowID"
	echo "Use -f to force download"
	exit -1
else
	echo -e '\nShowID: '"$1"'\n'
	number="$1"
fi

opath=/srv/mount/ssd0/now
date=$(date +'%y%m%d')

function getstream()
{
	wget -O "$opath"/content/"$date"_"$number".content https://now.naver.com/api/nnow/v1/stream/"$number"/content
	timeupdate
	exrefresh
	mkdir "$opath"/"$title"
	echo
	echo '방송시간: '"$starttime"' / 현재: '"$hour"':'"$min"':'"$sec"
	if [ $vcheck = 'true' ]
	then
		echo -e '\n'"$title"' E'"$ep"' '"$subjects"
		echo -e 'Audio: '"$url"'\nVideo: '"$vurl"'\n'
		echo -e '오디오 파일: '"$filenames"'.ts\n비디오 파일: '"$filenames"'_video.ts\n'
		# TODO 2)
		#countup &
		youtube-dl "$url" --output "$opath"/"$title"/"$filenames".ts &
		youtube-dl "$vurl" --output "$opath"/"$title"/"$filenames"_video.ts
		if [ "$?" =  '1' ]
		then
			echo -e '\n다운로드 실패, 3초 후 재시도'
			while :
			do
				timer=3
				counter
				echo
				wget -O "$opath"/content/"$date"_"$number".content https://now.naver.com/api/nnow/v1/stream/"$number"/content
				exrefresh
				# TODO 2)
				#slength=0
				youtube-dl "$url" --output "$opath"/"$title"/"$filenames".ts &
				youtube-dl "$vurl" --output "$opath"/"$title"/"$filenames"_video.ts
				if [ "$?" =  '1' ]
				then
					echo -e '\n다운로드 실패, 3초 후 재시도'
					#echo -e '\nslength: '"$slength"
				else
					echo -e '\n다운로드 성공'
					#echo -e '\nslength: '"$slength"
					break
				fi
			done
		fi
		# TODO 2)
		# 총 스트리밍길이가 1시간 미만일 경우
		#if [ "$slength" -lt 3600 ] && [ -z "$sfailcheck" ]
		#then
		#	while [ "$sfailcheck" -le 10 ]
		#	do
		#		sfailcheck=0
		#		: $((sfailcheck++))
		#		echo -e '\n방송이 정상 종료되지 않음, 5초 대기'
		#		timer=5
		#		counter
		#	done
		#fi
		echo -e '\n다운로드 완료, 3초 대기'
		#echo -e '\nslength: '"$slength"
		timer=3
		counter
	else
		echo -e '\n'"$title"' E'"$ep"' '"$subjects"'\n'"$url"'\n\n파일 이름: '"$filenames"'.ts\n'
		# TODO 2)
		#countup &
		youtube-dl "$url" --output "$opath"/"$title"/"$filenames".ts
		if [ "$?" =  '1' ]
		then
			echo -e '\n다운로드 실패, 3초 후 재시도'
			while :
			do
				timer=3
				counter
				echo
				wget -O "$opath"/content/"$date"_"$number".content https://now.naver.com/api/nnow/v1/stream/"$number"/content
				exrefresh
				# TODO 2)
				#slength=0
				youtube-dl "$url" --output "$opath"/"$title"/"$filenames".ts
				if [ "$?" =  '1' ]
				then
					echo -e '\n다운로드 실패, 3초 후 재시도'
					#echo -e '\nslength: '"$slength"
				else
					echo -e '\n다운로드 성공'
					#echo -e '\nslength: '"$slength"
					break
				fi
			done
		fi
		# TODO 2)
		# 총 스트리밍길이가 1시간 미만일 경우
		#if [ "$slength" -lt 3600 ] && [ -z "$sfailcheck" ]
		#then
		#	while [ "$sfailcheck" -le 10 ]
		#	do
		#		sfailcheck=0
		#		: $((sfailcheck++))
		#		echo -e '\n방송이 정상 종료되지 않음, 5초 대기'
		#		timer=5
		#		counter
		#	done
		#fi
		echo -e '\n다운로드 완료, 3초 대기'
		#echo -e '\nslength: '"$slength"
		timer=3
		counter
	fi
	codec=$(ffprobe -v error -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$opath"/"$title"/"$filenames".ts)
	if [ $codec = mp3 ]
	then 
		echo -e '\nCodec: MP3, Saving into mp3 file\n'
		ffmpeg -i "$opath"/"$title"/"$filenames".ts -vn -c:a copy "$opath"/"$title"/"$filenames".mp3
		echo -e '\nConvert Complete: '"$filenames"'.mp3'
	elif [ $codec = aac ]
	then
		echo -e '\nCodec: AAC, Saving into m4a file\n'
		ffmpeg -i "$opath"/"$title"/"$filenames".ts -vn -c:a copy "$opath"/"$title"/"$filenames".m4a
		echo -e '\nConvert Complete: '"$filenames"'.m4a'
	else
		echo -e '\nERROR: : Unable to get codec info\n'
		exit -1
	fi
}

function exrefresh()
{
	title=$(cat "$opath"/content/"$date"_"$number".content | grep -oP '"home":{"title":{"text":"\K[^"]+')
	url=$(cat "$opath"/content/"$date"_"$number".content | grep -oP 'streamUrl":"\K[^"]+')
	if [ $vcheck = 'true' ]
	then
		vurl=$(cat "$opath"/content/"$date"_"$number".content | grep -oP 'videoStreamUrl":"\K[^"]+')
	fi
	startdate=$(cat "$opath"/content/"$date"_"$number".content | grep -oP 'start":"20\K[^T]+')
	starttime=$(cat "$opath"/content/"$date"_"$number".content | grep -oP 'start":"\K[^"]+' | grep -oP 'T\K[^.+]+')
	subject=$(cat "$opath"/content/"$date"_"$number".content | grep -oP '},"title":{"text":"\K[^"]+')
	ep=$(cat "$opath"/content/"$date"_"$number".content | grep -oP '"count":"\K[^회"]+')
	#showhost=$(cat "$opath"/content/"$date"_"$number".content | grep -oP '"host":\["\K[^"]+')
	filename="$date"."NAVER NOW"."$title".E"$ep"."$subjects"_"$hour$min$sec"
	filenames=${filename//'/'/.}
	subjects=${subject//'\r\n'/}
	startdates=${startdate//'-'/}
	starttimes=${starttime//':'/}
	echo -e 'Exports refreshed\n'
}

function timeupdate()
{
	hour=$(date +'%H')
	min=$(date +'%M')
	sec=$(date +'%S')
	stimehr=$(expr substr "$starttimes" 1 2)
	stimemin=$(expr substr "$starttimes" 3 2)
	hourcheck=$(expr "$stimehr" - "$hour")
	mincheck=$(expr "$stimemin" - "$min")
	timecheck=$(echo "(($stimehr*60)+$stimemin)-(($hour*60)+$min)" | bc -l)
	echo -e 'Time refreshed\n'
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

# TODO 2)
function countup()
{
	echo -e 'countup initiated\n'
	slength=0
	while  [ $slength -lt 600 ]
	do
		((slength++))
		sleep 1
		#echo -ne 'slength: '"$slength\033[0K"'s'"\r"
	done
	echo -e '\nslength has reached '"$slength"'. terminating.'
	#unset slength
}

function diffdatesleep()
{
	while :
	do
		echo -e '방송일이 아닙니다\n'
		timeupdate	
		echo -e 'Time difference: '"$timecheck"' min'
		counter
		echo -e 'content 다시 불러오는 중...\n'
		wget -O "$opath"/content/"$date"_"$number".content https://now.naver.com/api/nnow/v1/stream/"$number"/content
		timeupdate
		exrefresh
		echo -e '방송일  : '"$startdates"' / 오늘: '"$date"
		echo '방송시간: '"$starttimes"' / 현재: '"$hour$min$sec"
		if [ $vcheck = 'true' ]
		then
			echo -e '\n'"$title"' E'"$ep"' '"$subjects"
			echo -e 'Audio: '"$url"'\nVideo: '"$vurl"'\n'
		else
			echo -e '\n'"$title"' E'"$ep"' '"$subjects"'\n'"$url"
		fi
		echo
		# 시작 시간이 65분 이상 차이
		if [ $timecheck -ge 65 ]
		then
			timer=3600
		# 시작 시간이 65분 미만 차이
		elif [ $timecheck -lt 65 ]
		then
			# 시작 시간이 10분 초과 차이
			if [ $timecheck -gt 10 ]
			then
				timer=600
			# 시작 시간이 10분 이하 차이
			elif [ $timecheck -le 10 ]
			then
				# 시작 시간이 2분 초과 차이
				if [ $timecheck -gt 2 ]
				then
					timer=60
				# 시작 시간이 2분 이하 차이
				elif [ $timecheck -le 2 ]
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
		if [ "$date" = "$startdates" ]
		then
			echo '방송일  : '"$startdates"' / 오늘: '"$date"
			echo '방송시간: '"$starttimes"' / 현재: '"$hour$min$sec"
			echo -e '\ncontent 불러오기 완료'
			break
		fi
	done
}

function samedatesleep()
{
	while :
	do
		echo -e '방송일입니다\n'
		timeupdate	
		echo -e 'Time difference: '"$timecheck"' min'
		counter
		echo -e 'content 다시 불러오는 중...\n'
		wget -O "$opath"/content/"$date"_"$number".content https://now.naver.com/api/nnow/v1/stream/"$number"/content
		timeupdate
		exrefresh
		echo -e '방송일  : '"$startdates"' / 오늘: '"$date"
		echo '방송시간: '"$starttimes"' / 현재: '"$hour$min$sec"
		if [ $vcheck = 'true' ]
		then
			echo -e '\n'"$title"' E'"$ep"' '"$subjects"
			echo -e 'Audio: '"$url"'\nVideo: '"$vurl"'\n'
		else
			echo -e '\n'"$title"' E'"$ep"' '"$subjects"'\n'"$url"
		fi
		echo
		# 시작시간과 현재시간의 차이가 음수일 경우 (시작시간보다 현재시간이 클 경우)
		if [ $timecheck -lt 0 ]
		then
			timer=0
		# 시작 시간이 65분 이상 차이
		elif [ $timecheck -ge 65 ]
		then
			timer=3600
		# 시작 시간이 65분 미만 차이
		elif [ $timecheck -ge 65 ]
		then
			# 시작 시간이 10분 초과 차이
			if [ $timecheck -ge 65 ]
			then
				timer=600
			# 시작 시간이 10분 이하 차이
			elif [ $timecheck -ge 65 ]
			then
				# 시작 시간이 2분 초과 차이
				if [ $timecheck -ge 65 ]
				then
					timer=60
				# 시작 시간이 2분 이하 차이
				elif [ $timecheck -ge 65 ]
				then
					timer=1
				else
					echo -e '\nERROR: 1-1n'
					exit -1
				fi
			else
				echo -e '\nERROR: 2-1\n'
				exit -1
			fi
		else
			echo -e '\nERROR: 3-1\n'
			exit -1
		fi
		# 시작일 확인
		if [ "$date" = "$startdates" ]
		then
			echo '방송일  : '"$startdates"' / 오늘: '"$date"
			echo '방송시간: '"$starttimes"' / 현재: '"$hour$min$sec"
			echo -e '\ncontent 불러오기 완료'
			exrefresh
			break
		fi
	done
}

wget -O "$opath"/content/"$date"_"$number".content https://now.naver.com/api/nnow/v1/stream/"$number"/content
vcheck=$(cat "$opath"/content/"$date"_"$number".content | grep -oP 'video":\K[^,]+')
exrefresh
timeupdate

if [ $vcheck = 'true' ]
then
	echo -e '비디오 스트림 발견, 함께 다운로드 합니다\n'
else
	echo -e '비디오 스트림 없음, 오디오만 다운로드 합니다\n'
fi

echo '방송일  : '"$startdates"' / 오늘: '"$date"
echo -e '방송시간: '"$starttimes"' / 현재: '"$hour$min$sec"'\n'

if [ $1 = "-f" ] && [ -n $2 ]
then
	echo -e '\nForce Download Enabled!\n'
	getstream
	echo -e '\nJob Finished, Code: -f\n'
	exit 0
fi

# 시작일이 다를 경우
if [ "$date" != "$startdates" ]
then
	timer=0
	diffdatesleep
	timeupdate
	# TODO 4)
	# 시작 시간이 됐을 경우
	if [ "$hour$min$sec" -ge "$starttimes" ]
	then
		echo -e '\n쇼가 시작됨\n'
		getstream
		echo -e '\nJob Finished, Code: 1\n'
	# 시작 시간이 안됐을 경우
	elif [ "$hour$min$sec" -lt "$starttimes" ]
	then
		echo -e '\n쇼가 아직 시작되지 않음'
		while :
		do
			echo '방송시간: '"$starttimes"' / 현재: '"$hour$min$sec"
			echo -e '\n대기 중...('"$hour$min$sec"')'
			sleep 1
			timeupdate			
			exrefresh
			# 시작 시간 확인
			if [ "$hour$min$sec" -ge "$starttimes" ]
			then
				echo '방송시간: '"$starttimes"' / 현재: '"$hour$min$sec"
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
elif [ "$date" = "$startdates" ]
then
	timer=0
	samedatesleep
	timeupdate
	# 시작 시간이 됐을 경우
	if [ "$hour$min$sec" -ge "$starttimes" ]
	then
		# 오전 방송일 경우
		# TODO 3)
		if [ "$starttimes" -gt 0 ] && [ "$starttimes" -lt 120000 ]
		then
			echo -e '오전 방송입니다\n'
			#abshr=$(echo "$hourcheck*-1" | bc -l)
			tillmid=$(echo "24-$hour" | bc -l)
			echo -e '남은 시간: 약 '"$(expr $stimehr + $tillmid)"'시간\n'
			#현재 시각에서 00시 까지 남은 시간 계산해서 counter 설정 후 00시 넘길 수 있게
			if [ "$hourcheck" -lt 0 ]
			then
				if [ "$abshr" -ge 1 ]
				then
					echo -e '방송일이 아님'
					while :
					do
						timer=300
						counter
						timeupdate			
						exrefresh
						# 시작 시간 확인
						if [ "$hourcheck" -ge 0 ]
						then
							echo -e '방송일이 아님'
							break
						fi
					done
				fi
			fi
		fi
		echo -e '\n * TEST POINT 1\n'
		#samedatesleep
		echo -e '쇼가 시작됨'
		getstream
		echo -e '\nJob Finished, Code: 3\n'
	# 시작 시간이 안됐을 경우
	elif [ "$hour$min$sec" -lt "$starttimes" ]
	then
		echo -e '\n쇼가 아직 시작되지 않음'
		while :
		do
			echo '방송시간: '"$starttimes"' / 현재: '"$hour$min$sec"
			echo -e '\n대기 중...('"$hour$min$sec"')'
			sleep 1
			timeupdate			
			exrefresh
			# 시작 시간 확인
			if [ "$hour$min$sec" -ge "$starttimes" ]
			then
				echo '방송시간: '"$starttimes"' / 현재: '"$hour$min$sec"
				echo -e '\n쇼가 시작됨\n'
				break
			fi
		done
		echo -e '\n * TEST POINT 2\n'
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