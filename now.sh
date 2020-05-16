#!/bin/bash

# TODO:
# 3) 오전 스트리밍 구분 추가
# 4) 날이 하루 이상 차이날 경우 12시간 타이머
# 5) diffdatesleep()와 samedatesleep() 합치기

# 스크립트 시작엔 contentget/exrefresh/timeupdate 순서, 이후 사용시 contentget/timeupdate/exrefresh 사용

# Color template: echo -e "${RED}TITLE${GRN}MESSAGE${NC}"
RED='\033[0;31m' # Error or force exit
YLW='\033[1;33m' # Warning or alert
GRN='\033[0;32m'
NC='\033[0m' # No Color

# directory to save; USE ORIGINAL LINK, NOT SYMLINKS
opath=/srv/mount/ssd0/now

if [ "$#" -eq 2 ]
then
	if [ "$1" = "-f" ]
	then
		if [ -z "$2" ]
		then
			echo "Usage: now (-f) ShowID"
			echo "Use -f to force download"
			exit -1
		else
			echo -e "${YLW}"'\nForce Download Enabled!'"${NC}"
			echo -e 'ShowID: '"$2"'\n'
			number="$2"
		fi
	else
		echo "Usage: now (-f) ShowID"
		echo "Use -f to force download"
		exit -1
	fi
elif [ "$#" -ne 1 ]
then
	echo "Usage: now (-f) ShowID"
	echo "Use -f to force download"
	exit -1
elif [ "$1" = "-f" ]
then
	echo "Usage: now (-f) ShowID"
	echo "Use -f to force download"
	exit -1
else
	echo -e '\nShowID: '"$1"'\n'
	number="$1"
fi

echo -n "Maximum download retry (Default: 10): "
read maxretry
if [ -z "$maxretry" ]
then
	maxretry=10
	echo -e "${YLW}"'Maximum retry set to default ('"$maxretry"')'"${NC}"
else
	echo -e "${YLW}"'Maximum retry set to '"$maxretry""${NC}"
fi
echo -ne "\nFailcheck streaming threshold (Default: 3300s): "
read ptimeth
if [ -z "$ptimeth" ]
then
	ptimeth=3300
	echo -e "${YLW}"'Failcheck threshold set to default ('"$ptimeth"')'"${NC}"
else
	echo -e "${YLW}"'Failcheck threshold set to '"$ptimeth""${NC}"
fi
echo

function contentget()
{
	ctlength=$(curl --head https://now.naver.com/api/nnow/v1/stream/$number/content | grep -oP 'content-length: \K[0-9]*')
	echo -e '\ncontent_length: '"$ctlength"
	if [ "$ctlength" -lt 2000 ]
	then
		retry=0
		while :
		do
			echo -e "${YLW}"'\ncontent 파일이 올바르지 않음, 1초 후 재시도'"${NC}"
			: $((retry++))
			timer=1
			counter
			echo -e '\n재시도 횟수: '"$retry"' / 최대 재시도 횟수: '"$maxretry"'\n'
			ctlength=$(curl --head https://now.naver.com/api/nnow/v1/stream/$number/content | grep -oP 'content-length: \K[0-9]*')
			if [ "$ctlength" -lt 2000 ]
			then
				if [ "$retry" -lt "$maxretry" ]
				then
					echo -e "${YLW}"'\n다운로드 실패, 3초 후 재시도'"${NC}"
				elif [ "$retry" -ge "$maxretry" ]
				then
					echo -e "${RED}"'\n다운로드 실패\n최대 재시도 횟수 초과, 스크립트 종료\n'"${NC}"
					exit -1
				else
					echo -e "${RED}"'\nERROR: contentget(): maxretry\n'"${NC}"
					exit -1
				fi
			elif [ "$ctlength" -ge 2000 ]
			then
				echo -e "${GRN}"'\n정상 content 파일\n'"${NC}"
				wget -O "$opath"/content/"$date"_"$number".content https://now.naver.com/api/nnow/v1/stream/"$number"/content
				break
			else
				echo -e "${RED}"'\nERROR: contentget(): ctlength 1\n'"${NC}"
				exit -1
			fi
		done
		unset retry
	elif [ "$ctlength" -ge 2000 ]
	then
		echo -e "${GRN}"'\n정상 content 파일\n'"${NC}"
		wget -O "$opath"/content/"$date"_"$number".content https://now.naver.com/api/nnow/v1/stream/"$number"/content
	else
		echo -e "${RED}"'\nERROR: contentget(): ctlength 2\n'"${NC}"
		exit -1
	fi
}

function getstream()
{
	contentget
	timeupdate
	exrefresh
	echo '방송시간: '"$starttime"' / 현재: '"$hour"':'"$min"':'"$sec"
	if [ "$vcheck" = 'true' ]
	then
		echo -e '\n'"$title"' E'"$ep"' '"$subjects"
		echo -e 'Audio: '"$url"'\nVideo: '"$vurl"'\n'
		echo -e '오디오 파일: '"$filenames"'.ts\n비디오 파일: '"$filenames"'_video.ts\n'
		youtube-dl "$url" --output "$opath"/show/"$title"/"$filenames".ts &
		youtube-dl "$vurl" --output "$opath"/show/"$title"/"$filenames"_video.ts
		if [ "$?" =  '1' ]
		then
			echo -e "${YLW}"'\n다운로드 실패, 1초 후 재시도'"${NC}"
			retry=0
			while :
			do
				timer=1
				counter
				: $((retry++))
				echo -e '\n재시도 횟수: '"$retry"'\n'
				wget -O "$opath"/content/"$date"_"$number".content https://now.naver.com/api/nnow/v1/stream/"$number"/content
				timeupdate
				exrefresh
				youtube-dl "$url" --output "$opath"/show/"$title"/"$filenames".ts &
				youtube-dl "$vurl" --output "$opath"/show/"$title"/"$filenames"_video.ts
				if [ "$?" =  '1' ]
				then
					if [ "$retry" -lt "$maxretry" ]
					then
						echo -e "${YLW}"'\n다운로드 실패, 1초 후 재시도'"${NC}"
					elif [ "$retry" -ge "$maxretry" ]
					then
						echo -e "${RED}"'\n다운로드 실패\n최대 재시도 횟수 초과, 스크립트 종료\n'"${NC}"
						exit -1
					else
						echo -e "${RED}"'\nERROR: getstream(): maxretry 1\n'"${NC}"
						exit -1
					fi
				else
					echo -e "${GRN}"'\n다운로드 성공'"${NC}"
					echo -e '\n총 재시도 횟수: '"$retry"
					unset retry
					break
				fi
			done
		fi
		echo -e "${GRN}"'\n다운로드 완료, 3초 대기'"${NC}"
		timer=3
		counter
	else
		echo -e '\n'"$title"' E'"$ep"' '"$subjects"'\n'"$url"'\n\n파일 이름: '"$filenames"'.ts\n'
		youtube-dl "$url" --output "$opath"/show/"$title"/"$filenames".ts
		if [ "$?" =  '1' ]
		then
			echo -e "${YLW}"'\n다운로드 실패, 1초 후 재시도'"${NC}"
			retry=0
			while :
			do
				timer=1
				counter
				: $((retry++))
				echo -e '\n재시도 횟수: '"$retry"' / 최대 재시도 횟수: '"$maxretry"'\n'
				wget -O "$opath"/content/"$date"_"$number".content https://now.naver.com/api/nnow/v1/stream/"$number"/content
				timeupdate
				exrefresh
				youtube-dl "$url" --output "$opath"/show/"$title"/"$filenames".ts
				if [ "$?" =  '1' ]
				then
					if [ "$retry" -lt "$maxretry" ]
					then
						echo -e "${YLW}"'\n다운로드 실패, 1초 후 재시도'"${NC}"
					elif [ "$retry" -ge "$maxretry" ]
					then
						echo -e "${RED}"'\n다운로드 실패\n최대 재시도 횟수 초과, 스크립트 종료\n'"${NC}"
						exit -1
					else
						echo -e "${RED}"'\nERROR: getstream(): maxretry 2\n'"${NC}"
						exit -1
					fi
				else
					echo -e "${GRN}"'\n다운로드 성공'"${NC}"
					echo -e '\n총 재시도 횟수: '"$retry"
					unset retry
					break
				fi
			done
		fi
		echo -e "${GRN}"'\n다운로드 완료, 3초 대기'"${NC}"
		timer=3
		counter
	fi
	# TODO 2)
	# 총 스트리밍길이가 $ptimeth 이하일 경우 15초 대기 후 재시작
	ptime=$(ffprobe -v error -show_entries stream=duration -of default=noprint_wrappers=1:nokey=1 "$opath"/show/"$title"/"$filenames".ts | grep -o '^[^.]*')
	echo -e '\n스트리밍 시간: '"$ptime"'s / 스트리밍 정상 종료 기준: '"$ptimeth"'s'
	if [ "$ptime" -lt "$ptimeth" ]
	then
		if [ -z "$sfailcheck" ]
		then
			echo -e "${RED}"'\n스트리밍이 정상 종료되지 않음, 15초 후 재시작'"${NC}"
			sfailcheck=1
			timer=15
			counter
			getstream
		elif [ -n "$sfailcheck" ]
		then
			echo -e "${GRN}"'\n스트리밍이 정상 종료됨'"${NC}"
			convert
		else
			echo -e "${RED}"'\nERROR: sfailcheck\n'"${NC}"
		fi
	elif [ "$ptime" -ge "$ptimeth" ]
	then
		echo -e "${GRN}"'\n스트리밍이 정상 종료됨'"${NC}"
		convert
	else
		echo -e "${RED}"'\nERROR: ptime/ptimeth\n'"${NC}"
	fi
}

function convert()
{
	codec=$(ffprobe -v error -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$opath"/show/"$title"/"$filenames".ts)
	if [ "$codec" = 'mp3' ]
	then 
		echo -e '\nCodec: MP3, Saving into mp3 file\n'
		ffmpeg -i "$opath"/show/"$title"/"$filenames".ts -vn -c:a copy "$opath"/show/"$title"/"$filenames".mp3
		echo -e '\nConvert Complete: '"$filenames"'.mp3'
	elif [ "$codec" = 'aac' ]
	then
		echo -e '\nCodec: AAC, Saving into m4a file\n'
		ffmpeg -i "$opath"/show/"$title"/"$filenames".ts -vn -c:a copy "$opath"/show/"$title"/"$filenames".m4a
		echo -e '\nConvert Complete: '"$filenames"'.m4a'
	else
		echo -e "${RED}"'\nERROR: : Unable to get codec info\n'"${NC}"
		exit -1
	fi
}

function exrefresh()
{
	title=$(cat "$opath"/content/"$date"_"$number".content | grep -oP '"home":{"title":{"text":"\K[^"]+')
	url=$(cat "$opath"/content/"$date"_"$number".content | grep -oP 'streamUrl":"\K[^"]+')
	if [ "$vcheck" = 'true' ]
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
	echo -e "${YLW}"'Exports refreshed\n'"${NC}"
}

function timeupdate()
{
    date=$(date +'%y%m%d')
	hour=$(date +'%H')
	min=$(date +'%M')
	sec=$(date +'%S')
	stimehr=$(expr substr "$starttimes" 1 2)
	stimemin=$(expr substr "$starttimes" 3 2)
	hourcheck=$(expr "$stimehr" - "$hour")
	mincheck=$(expr "$stimemin" - "$min")
	timecheck=$(echo "(($stimehr*60)+$stimemin)-(($hour*60)+$min)" | bc -l)
	echo -e "${YLW}"'Time refreshed\n'"${NC}"
}

function counter()
{
	echo
	while [ "$timer" -gt 0 ]
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
		echo -e 'Time difference: '"$timecheck"' min'
		counter
		echo -e 'content 다시 불러오는 중...\n'
		contentget
		timeupdate
		exrefresh
		echo -e '방송일  : '"$startdates"' / 오늘: '"$date"
		echo '방송시간: '"$starttimes"' / 현재: '"$hour$min$sec"
		if [ "$vcheck" = 'true' ]
		then
			echo -e '\n'"$title"' E'"$ep"' '"$subjects"
			echo -e 'Audio: '"$url"'\nVideo: '"$vurl"'\n'
		else
			echo -e '\n'"$title"' E'"$ep"' '"$subjects"'\n'"$url"
		fi
		echo
		# 시작 시간이 65분 이상 차이
		if [ "$timecheck" -ge 65 ]
		then
			timer=3600
		# 시작 시간이 65분 미만 차이
		elif [ "$timecheck" -lt 65 ]
		then
			# 시작 시간이 10분 초과 차이
			if [ "$timecheck" -gt 10 ]
			then
				timer=600
			# 시작 시간이 10분 이하 차이
			elif [ "$timecheck" -le 10 ]
			then
				# 시작 시간이 2분 초과 차이
				if [ "$timecheck" -gt 2 ]
				then
					timer=60
				# 시작 시간이 2분 이하 차이
				elif [ "$timecheck" -le 2 ]
				then
					timer=1
				else
					echo -e "${RED}"'\nERROR: diffdatesleep(): 1\n'"${NC}"
					exit -1
				fi
			else
				echo -e "${RED}"'\nERROR: diffdatesleep(): 2\n'"${NC}"
				exit -1
			fi
		else
			echo -e "${RED}"'\nERROR: diffdatesleep(): 3\n'"${NC}"
			exit -1
		fi
		# 시작일 확인
		if [ "$date" = "$startdates" ]
		then
			echo '방송일  : '"$startdates"' / 오늘: '"$date"
			echo '방송시간: '"$starttimes"' / 현재: '"$hour$min$sec"
			echo -e "${GRN}"'\ncontent 불러오기 완료\n'"${NC}"
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
		if [ "$vcheck" = 'true' ]
		then
			echo -e '\n'"$title"' E'"$ep"' '"$subjects"
			echo -e 'Audio: '"$url"'\nVideo: '"$vurl"'\n'
		else
			echo -e '\n'"$title"' E'"$ep"' '"$subjects"'\n'"$url"
		fi
		echo
		# 시작시간과 현재시간의 차이가 음수일 경우 (시작시간보다 현재시간이 클 경우)
		if [ "$timecheck" -lt 0 ]
		then
			timer=0
			# 시작 시간이 65분 이상 차이
			if [ "$timecheck" -ge 65 ]
			then
				timer=3600
			# 시작 시간이 65분 미만 차이
			elif [ "$timecheck" -lt 65 ]
			then
				# 시작 시간이 10분 초과 차이
				if [ "$timecheck" -gt 10 ]
				then
					timer=600
				# 시작 시간이 10분 이하 차이
				elif [ "$timecheck" -le 10 ]
				then
					# 시작 시간이 2분 초과 차이
					if [ "$timecheck" -gt 2 ]
					then
						timer=60
					# 시작 시간이 2분 이하 차이
					elif [ "$timecheck" -le 2 ]
					then
						timer=1
					else
						echo -e "${RED}"'\nERROR: samedatesleep(): 1\n'"${NC}"
						exit -1
					fi
				else
					echo -e "${RED}"'\nERROR: samedatesleep(): 2\n'"${NC}"
					exit -1
				fi
			fi
		else
			echo -e "${RED}"'\nERROR: samedatesleep(): 3\n'"${NC}"
			exit -1
		fi
		# 시작일 확인
		if [ "$date" = "$startdates" ]
		then
			echo '방송일  : '"$startdates"' / 오늘: '"$date"
			echo '방송시간: '"$starttimes"' / 현재: '"$hour$min$sec"
			echo -e "${GRN}"'\ncontent 불러오기 완료\n'"${NC}"
			exrefresh
			break
		fi
	done
}

# Start of script
if [ ! -d "$opath"/content ]
then
    echo -e "${YLW}"'content folder does not exitst, creating...\n'"${NC}"
    mkdir "$opath"/content
else
    echo -e 'content folder exists\n'
fi
if [ ! -d "$opath"/log ]
then
    echo -e "${YLW}"'log folder does not exitst, creating...\n'"${NC}"
    mkdir "$opath"/log
else
    echo -e 'log folder exists\n'
fi
if [ ! -d "$opath"/show ]
then
    echo -e "${YLW}"'show folder does not exitst, creating...\n'"${NC}"
    mkdir "$opath"/show
else
    echo -e 'show folder exists\n'
fi

date=$(date +'%y%m%d')
wget -O "$opath"/content/"$date"_"$number".content https://now.naver.com/api/nnow/v1/stream/"$number"/content
vcheck=$(cat "$opath"/content/"$date"_"$number".content | grep -oP 'video":\K[^,]+')
exrefresh
timeupdate

if [ "$vcheck" = 'true' ]
then
	echo -e "${YLW}"'비디오 스트림 발견, 함께 다운로드 합니다\n'"${NC}"
else
	echo -e "${YLW}"'비디오 스트림 없음, 오디오만 다운로드 합니다\n'"${NC}"
fi

echo '방송일  : '"$startdates"' / 오늘: '"$date"
echo -e '방송시간: '"$starttimes"' / 현재: '"$hour$min$sec"'\n'

if [ "$1" = "-f" ] && [ -n "$2" ]
then
	echo -e "${YLW}"'Force Download Enabled!\n'"${NC}"
	getstream
	echo -e "${GRN}"'\nJob Finished, Code: -f\n'"${NC}"
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
		echo -e "${YLW}"'쇼가 시작됨\n'"${NC}"
		getstream
		echo -e "${GRN}"'\nJob Finished, Code: 1\n'"${NC}"
	# 시작 시간이 안됐을 경우
	elif [ "$hour$min$sec" -lt "$starttimes" ]
	then
		echo -e '쇼가 아직 시작되지 않음\n'
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
				echo -e "${YLW}"'쇼가 시작됨\n'"${NC}"
				break
			fi
		done
		getstream
		echo -e "${GRN}"'\nJob Finished, Code: 2\n'"${NC}"
	else
		echo -e "${RED}"'\nERROR: 1\n'"${NC}"
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
		#if [ "$starttimes" -gt 0 ] && [ "$starttimes" -lt 120000 ]
		#then
		#	echo -e '오전 방송입니다\n'
		#	#abshr=$(echo "$hourcheck*-1" | bc -l)
		#	tillmid=$(echo "24-$hour" | bc -l)
		#	echo -e '남은 시간: 약 '"$(expr $stimehr + $tillmid)"'시간\n'
		#	#현재 시각에서 00시 까지 남은 시간 계산해서 counter 설정 후 00시 넘길 수 있게
		#	if [ "$hourcheck" -lt 0 ]
		#	then
		#		if [ "$abshr" -ge 1 ]
		#		then
		#			echo -e '방송일이 아님'
		#			while :
		#			do
		#				timer=300
		#				counter
		#				timeupdate
		#				exrefresh
		#				# 시작 시간 확인
		#				if [ "$hourcheck" -ge 0 ]
		#				then
		#					echo -e '방송일이 아님'
		#					break
		#				fi
		#			done
		#		fi
		#	fi
		#fi
		echo -e "${YLW}"'\n * TEST POINT 1\n'"${NC}"
		#samedatesleep
		echo -e "${YLW}"'쇼가 시작됨\n'"${NC}"
		getstream
		echo -e "${GRN}"'\nJob Finished, Code: 3\n'"${NC}"
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
				echo -e "${YLW}"'쇼가 시작됨\n'"${NC}"
				break
			fi
		done
		echo -e "${YLW}"'\n * TEST POINT 2\n'"${NC}"
		getstream
		echo -e "${GRN}"'\nJob Finished, Code: 4\n'"${NC}"
	else
		echo -e "${RED}"'\nERROR: 2\n'"${NC}"
		exit -1
	fi
else
	echo -e "${RED}"'\nERROR: 3\n'"${NC}"
	exit -1
fi