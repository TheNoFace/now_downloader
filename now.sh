#!/bin/bash

# TODO:
# 3) 오전 스트리밍 구분 추가
# 4) 날이 하루 이상 차이날 경우 12시간 타이머 -> 시작일자 입력해서 하루 이상 차이나면 12시간 타이머
# 5) diffdatesleep()와 samedatesleep() 합치기
# 6) 방송 시각과 현재 시각 차이가 20분 이상이면 (시각차이-20)분 sleep

# 스크립트 시작엔 contentget/exrefresh/timeupdate 순서, 이후 사용시 contentget/timeupdate/exrefresh 사용

# Color template: echo -e "${RED}TITLE${GRN}MESSAGE${NC}"
RED='\033[0;31m' # Error or force exit
YLW='\033[1;33m' # Warning or alert
GRN='\033[0;32m'
NC='\033[0m' # No Color

opath=/srv/mount/ssd0/now # directory to save; USE ORIGINAL LINK, NOT SYMLINKS
today=$(date +'%Y-%m-%d')

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
			force=1
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
# TODO 4)
echo -ne "\nCustom start date (Today: $today / Skip if you don't want): "
read cusdate
if [ -z "$cusdate" ]
then
	echo -e "${YLW}Custom start date is not set${NC}"
else
	echo -e "${YLW}Custom start date set to $cusdate${NC}"
fi
echo -ne "\nCustom sleep timer before starting script (in seconds / Skip if you don't want): "
read custimer
if [ -z "$custimer" ]
then
	echo -e "${YLW}Custom sleep timer is not set${NC}"
else
	echo -e "${YLW}Custom sleep timer set to $custimer${NC}"
fi
echo

if [ ! -d "$opath"/content ]
then
	echo -e "${YLW}content folder does not exitst, creating...\n${NC}"
	mkdir "$opath"/content
else
	echo -e 'content folder exists\n'
fi
if [ ! -d "$opath"/log ]
then
	echo -e "${YLW}log folder does not exitst, creating...\n${NC}"
	mkdir "$opath"/log
else
	echo -e 'log folder exists\n'
fi
if [ ! -d "$opath"/show ]
then
	echo -e "${YLW}show folder does not exitst, creating...\n${NC}"
	mkdir "$opath"/show
else
	echo -e 'show folder exists\n'
fi

# content: general information of show
# livestatus: audio/video stream information of show
function contentget()
{
	ctlength=$(curl --head https://now.naver.com/api/nnow/v1/stream/$number/content | grep -oP 'content-length: \K[0-9]*')
	lslength=$(curl --head https://now.naver.com/api/nnow/v1/stream/$number/livestatus | grep -oP 'content-length: \K[0-9]*')
	echo -e "\nctlength: $ctlength / lslength: $lslength"
	if [ "$ctlength" -lt 2000 ] && [ "$lslength" -lt 1000 ]
	then
		ctretry=0
		echo -e "${YLW}\ncontent/livestatus 파일이 올바르지 않음, 1초 후 재시도${NC}"
		while :
		do
			((ctretry++))
			timer=1
			counter
			echo -e "재시도 횟수: $ctretry / 최대 재시도 횟수: $maxretry\n"
			ctlength=$(curl --head https://now.naver.com/api/nnow/v1/stream/$number/content | grep -oP 'content-length: \K[0-9]*')
			lslength=$(curl --head https://now.naver.com/api/nnow/v1/stream/$number/livestatus | grep -oP 'content-length: \K[0-9]*')
			echo -e "\nctlength: $ctlength / lslength: $lslength"
			if [ "$ctlength" -lt 2000 ] && [ "$lslength" -lt 1000 ]
			then
				if [ "$ctretry" -lt "$maxretry" ]
				then
					echo -e "${YLW}\ncontent/livestatus 파일이 올바르지 않음, 1초 후 재시도${NC}"
				elif [ "$ctretry" -ge "$maxretry" ]
				then
					echo -e "${RED}\n다운로드 실패\n최대 재시도 횟수($maxretry회) 도달, 스크립트 종료\n${NC}"
					exit -1
				else
					echo -e "${RED}\nERROR: contentget(): ctretry,maxretry\n${NC}"
					exit -1
				fi
			elif [ "$ctlength" -ge 2000 ] && [ "$lslength" -ge 1000 ]
			then
				echo -e "${GRN}\n정상 content/livestatus 파일\n${NC}"
				wget -O "$opath"/content/"$date"_"$number".content https://now.naver.com/api/nnow/v1/stream/"$number"/content
				wget -O "$opath"/content/"$date"_"$number".livestatus https://now.naver.com/api/nnow/v1/stream/"$number"/livestatus
				break
			else
				echo -e "${RED}"'\nERROR: contentget(): ctlength 1\n'"${NC}"
				exit -1
			fi
		done
		unset ctretry
	elif [ "$ctlength" -ge 2000 ] && [ "$lslength" -ge 1000 ]
	then
		echo -e "${GRN}\n정상 content/livestatus 파일\n${NC}"
		wget -O "$opath"/content/"$date"_"$number".content https://now.naver.com/api/nnow/v1/stream/"$number"/content
		wget -O "$opath"/content/"$date"_"$number".livestatus https://now.naver.com/api/nnow/v1/stream/"$number"/livestatus
		unset ctretry
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
		echo -e "${YLW}\n비디오 스트림 발견, 함께 다운로드 합니다\n${NC}"
		echo -e '\n'"$title"' E'"$ep"' '"$subjects"
		echo -e 'Audio: '"$url"'\nVideo: '"$vurl"'\n'
		echo -e '오디오 파일: '"$filenames"'.ts\n비디오 파일: '"$filenames"'_video.ts\n'
		youtube-dl "$url" --output "$opath"/show/"$title"/"$filenames".ts &
		youtube-dl "$vurl" --output "$opath"/show/"$title"/"$filenames"_video.ts
		gsretry
	else
		echo -e "${YLW}\n비디오 스트림 없음, 오디오만 다운로드 합니다${NC}"
		echo -e '\n'"$title"' E'"$ep"' '"$subjects"'\n'"$url"'\n\n파일 이름: '"$filenames"'.ts\n'
		youtube-dl "$url" --output "$opath"/show/"$title"/"$filenames".ts
		gsretry
	fi
	ptime=$(ffprobe -v error -show_entries stream=duration -of default=noprint_wrappers=1:nokey=1 "$opath"/show/"$title"/"$filenames".ts | grep -o '^[^.]*')
	echo -e "스트리밍 시간: $ptime초 / 스트리밍 정상 종료 기준: $ptimeth초"
	if [ "$ptime" -lt "$ptimeth" ]
	then
		if [ -z "$sfailcheck" ]
		then
			echo -e "${RED}\n스트리밍이 정상 종료되지 않음, 20초 후 재시작${NC}"
			sfailcheck=1
			timer=20
			counter
			getstream
		elif [ -n "$sfailcheck" ]
		then
			echo -e "${GRN}"'\n스트리밍이 정상 종료됨'"${NC}"
			convert
		else
			echo -e "${RED}"'\nERROR: sfailcheck\n'"${NC}"
			exit -1
		fi
	elif [ "$ptime" -ge "$ptimeth" ]
	then
		echo -e "${GRN}"'\n스트리밍이 정상 종료됨'"${NC}"
		convert
	else
		echo -e "${RED}"'\nERROR: ptime/ptimeth\n'"${NC}"
		exit -1
	fi
}

function gsretry()
{
	if [ "$?" =  '1' ]
	then
		if [ "$maxretry" = 0 ]
		then
			echo -e "${RED}\n다운로드 실패, 스크립트 종료\n${NC}"
			exit -1
		fi
		if [ -n "$retry" ]
		then
			echo -e "\n재시도 횟수: $retry / 최대 재시도 횟수: $maxretry"
		fi
		if [ -z "$retry" ] || [ "$retry" -lt "$maxretry" ]
		then
			echo -e "${YLW}\n다운로드 실패, 재시도 합니다\n${NC}"
			((retry++))
		elif [ "$retry" -ge "$maxretry" ]
		then
			echo -e "${RED}\n다운로드 실패\n최대 재시도 횟수($maxretry회) 도달, 스크립트 종료\n${NC}"
			exit -1
		else
			echo -e "${RED}\nERROR: getstream(): maxretry 1\n${NC}"
			exit -1
		fi
		getstream
	else
		if [ -z "$retry" ]
		then
			retry=0
		fi
		echo -e "${GRN}\n다운로드 성공${NC}"
		echo -e "\n총 재시도 횟수: $retry"
	fi
	unset retry
	echo -e "${GRN}\n다운로드 완료, 3초 대기${NC}"
	timer=3
	counter
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
	echo -e "${GRN}\nJob Finished, Code: $sreason\n${NC}"
	exit 0
}

function exrefresh()
{
	title=$(cat "$opath"/content/"$date"_"$number".content | grep -oP 'home":{"title":{"text":"\K[^"]+')
	url=$(cat "$opath"/content/"$date"_"$number".livestatus | grep -oP 'liveStreamUrl":"\K[^"]+')
	vcheck=$(cat "$opath"/content/"$date"_"$number".content | grep -oP 'video":\K[^,]+')
	if [ "$vcheck" = 'true' ]
	then
		vurl=$(cat "$opath"/content/"$date"_"$number".livestatus | grep -oP 'videoStreamUrl":"\K[^"]+')
	fi
	startdate=$(cat "$opath"/content/"$date"_"$number".content | grep -oP 'start":"20\K[^T]+')
	#enddate=$(cat "$opath"/content/"$date"_"$number".livestatus | grep -oP '"endDatetime":"20\K[^T]+')
	starttime=$(cat "$opath"/content/"$date"_"$number".content | grep -oP 'start":"\K[^"]+' | grep -oP 'T\K[^.+]+')
	subject=$(cat "$opath"/content/"$date"_"$number".content | grep -oP '},"title":{"text":"\K[^"]+')
	ep=$(cat "$opath"/content/"$date"_"$number".content | grep -oP '"count":"\K[^회"]+')
	#showhost=$(cat "$opath"/content/"$date"_"$number".content | grep -oP '"host":\["\K[^"]+')
	onair=$(cat "$opath"/content/"$date"_"$number".livestatus | grep -oP $number'","status":"\K[^"]+') # READY | ONAIR
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
	#hourcheck=$(expr "$stimehr" - "$hour")
	#mincheck=$(expr "$stimemin" - "$min")
	timecheck=$(echo "($stimehr*60+$stimemin)-($hour*60+$min)" | bc -l)
	echo -e "${YLW}"'Time refreshed\n'"${NC}"
}

function counter()
{
	echo -e '\n총 '"$timer"'초 동안 대기합니다'
	while [ "$timer" -gt 0 ]
	do
		echo -ne "$timer\033[0K"'초 남음'"\r"
		sleep 1
		((timer--))
	done
	unset timer
	echo -e '\n'
}

function diffdatesleep()
{
	while :
	do
		echo -e '방송일이 아닙니다\n'
		timeupdate	
		echo -e 'Time difference: '"$timecheck"' min'
		counter
		echo -e 'content/livestatus 다시 불러오는 중...\n'
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
		# TODO 4)
		if [ -n "$cusdate" ]
		then
			while :
			do
				todate=$(date +'%d')
				datediff=$(expr "$cusdate" - "$todate")
				echo -e '사용자 설정 방송 일자 차이: '"$datediff"
				if [ "$datediff" -gt 1 ]
				then
					echo -e "${YLW}\n방송일($cusdate일)이 하루 이상 남았습니다\n24시간 동안 대기합니다${NC}"
					timer=86400
					counter
				elif [ "$datediff" -le 1 ]
				then
					echo -e "${YLW}\n방송일이 하루 이하 남았습니다${NC}"
					break
				else
					echo -e "${RED}\nERROR: diffdatesleep(): cusdate,stdate,datediff 1 \n${NC}"
					exit -1
				fi
			done
		elif [ -z "$cusdate" ]
		then
			echo -e "${YLW}설정된 방송일이 없습니다\n${NC}"
		else
			echo -e "${RED}\nERROR: diffdatesleep(): cusdate,stdate,datediff 1 \n${NC}"
			exit -1
		fi
		# TODO 4)
		#if [ "$stimehr" -lt 12 ] && [ "$hour" -gt 12] # 시작 시간이 오전, 현재 시간이 오후일 경우
		#then
		#	breakhr=$(echo "($stimehr+24-$hour-1)*60*60 | bc -l)
		#	timer=$breakhr
		#	counter
		#if [ $(expr $stimehr + 24 - $hour) -gt 1 ] # 시작 시간과 현재 시간이 1시간 이상 차이
		# 시작 시간이 65분 이상 차이
		if [ "$timecheck" -ge 65 ]
		then
			timer=3600
		# 시작 시간이 65분 미만 차이
		elif [ "$timecheck" -lt 65 ]
		then
			# 시작 시간이 10분 초과 차이
			if [ "$timecheck" -gt 12 ]
			then
				timer=600
			# 시작 시간이 10분 이하 차이
			elif [ "$timecheck" -le 12 ]
			then
				# 시작 시간이 2분 초과 차이
				if [ "$timecheck" -gt 3 ]
				then
					timer=60
				# 시작 시간이 2분 이하 차이
				elif [ "$timecheck" -le 3 ]
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
		# 방송 상태 확인
		if [ "$onair" = "READY" ]
		then
			echo -e "Live Status: ${YLW}$onair\n${NC}"
		elif [ "$onair" = "ONAIR" ]
		then
			echo -e "Live Status: ${GRN}$onair\n${NC}"
			break
		else
			echo -e "${RED}\nERROR: diffdatesleep(): onair\n${NC}"
			exit -1
		fi
		#if [ "$date" = "$startdates" ]
		#then
		#	echo '방송일  : '"$startdates"' / 오늘: '"$date"
		#	echo '방송시간: '"$starttimes"' / 현재: '"$hour$min$sec"
		#	echo -e "${GRN}"'\ncontent 불러오기 완료\n'"${NC}"
		#	break
		#fi
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
		# TODO 4)
		if [ -n "$cusdate" ]
		then
			while :
			do
				todate=$(date +'%d')
				datediff=$(expr "$cusdate" - "$todate")
				echo -e '사용자 설정 방송 일자 차이: '"$datediff"
				if [ "$datediff" -gt 1 ]
				then
					echo -e "${YLW}\n방송일($cusdate일)이 하루 이상 남았습니다\n24시간 동안 대기합니다${NC}"
					timer=86400
					counter
				elif [ "$datediff" -le 1 ]
				then
					echo -e "${YLW}\n방송일이 하루 이하 남았습니다${NC}"
					break
				else
					echo -e "${RED}\nERROR: diffdatesleep(): cusdate,stdate,datediff 1 \n${NC}"
					exit -1
				fi
			done
		elif [ -z "$cusdate" ]
		then
			echo -e "${YLW}설정된 방송일이 없습니다\n${NC}"
		else
			echo -e "${RED}\nERROR: diffdatesleep(): cusdate,stdate,datediff 1 \n${NC}"
			exit -1
		fi
		# TODO 4)
		#if [ "$stimehr" -lt 12 ] && [ "$hour" -gt 12] # 시작 시간이 오전, 현재 시간이 오후일 경우
		#then
		#	breakhr=$(echo "($stimehr+24-$hour-1)*60*60 | bc -l)
		#	timer=$breakhr
		#	counter
		#if [ $(expr $stimehr + 24 - $hour) -gt 1 ] # 시작 시간과 현재 시간이 1시간 이상 차이
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

# Start of script
date=$(date +'%y%m%d')
contentget
exrefresh
timeupdate

if [ "$vcheck" = 'true' ]
then
	echo -e "${YLW}"'비디오 스트림 발견, 함께 다운로드 합니다\n'"${NC}"
else
	echo -e "${YLW}"'비디오 스트림 없음, 오디오만 다운로드 합니다\n'"${NC}"
fi

echo '방송일  : '"$startdates"' / 오늘: '"$date"
echo -e "방송시간: $starttimes / 현재: $hour$min$sec"
echo -e "$title E$ep $subjects\n"

if [ -n "$custimer" ]
then
	echo -e "${YLW}사용자가 설정한 시작 대기 타이머가 존재합니다 ($custimer초)${NC}"
	timer=$custimer
	counter
	unset timer
	contentget
	exrefresh
	timeupdate
elif [ -z "$custimer" ]
then
	echo -e "사용자가 설정한 시작 대기 타이머가 없음\n"
	contentget
	exrefresh
	timeupdate
else
	echo -e "${RED}\nERROR: custimer\n${NC}"
	exit -1
fi

if [ "$force" = "1" ] && [ -n "$number" ]
then
	echo -e "${YLW}Force Download Enabled!\n${NC}"
	sreason="-f"
	getstream
fi

# 시작일이 다를 경우
if [ "$date" != "$startdates" ]
then
	timer=0
	diffdatesleep
	contentget
	timeupdate
	exrefresh
	# 시작 시간이 됐을 경우
	if [ "$hour$min$sec" -ge "$starttimes" ]
	then
		echo -e "${YLW}"'쇼가 시작됨\n'"${NC}"
		sreason=1
		getstream
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
		sreason=2
		getstream
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
		sreason=3
		getstream
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
		sreason=4
		getstream
	else
		echo -e "${RED}"'\nERROR: 2\n'"${NC}"
		exit -1
	fi
else
	echo -e "${RED}"'\nERROR: 3\n'"${NC}"
	exit -1
fi

echo -e "${RED}"'\nERROR: EOF\n'"${NC}"
exit -1