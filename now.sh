#!/bin/bash

# TODO:
# 200531-1) 방송 시각과 현재 시각 차이가 20분 이상이면 (시각차이-20)분 sleep
# 200531-2) ERROR CHECK에 $vcheck = true일 경우 오디오/비디오 스트림 동시에 받기

# contentget -> exrefresh -> timeupdate

# Color template: echo -e "${RED}TITLE${GRN}MESSAGE${NC}"
RED='\033[0;31m' # Error or force exit
YLW='\033[1;33m' # Warning or alert
GRN='\033[0;32m'
NC='\033[0m' # No Color

STMSG=("\n--SCRIPT-START------$(date +'%F %a %T')--------------------------------\n")

if [ "$#" -eq 2 ]
then
	if [ "$1" = "-f" ]
	then
		if [ -z "$2" ]
		then
			echo "Usage: now (-f) ShowID"
			echo "Use -f to force download"
			exit 1
		else
			echo -e ${STMSG}
			echo -e "${YLW}Force Download Enabled!${NC}"
			echo -e "ShowID: $2\n"
			number="$2"
			force=1
		fi
	else
		echo "Usage: now (-f) ShowID"
		echo "Use -f to force download"
		exit 1
	fi
elif [ "$#" -ne 1 ]
then
	echo "Usage: now (-f) ShowID"
	echo "Use -f to force download"
	exit 1
elif [ "$1" = "-f" ]
then
	echo "Usage: now (-f) ShowID"
	echo "Use -f to force download"
	exit 1
else
	echo -e ${STMSG}
	echo -e "ShowID: $1\n"
	number="$1"
fi

if [ ! -e .opath ]
then
	echo "Seems like it's your first time to run this scipt"
	echo -n "Please enter directory to save (e.g: /home/$USER/now): "
	read opath
	if [ ! -d ${opath} ]
	then
		echo -e "Output Directory: $opath"
		echo -e "\n${RED}ERROR: Directory is not available"
		echo -e "Are you sure that directory exists?${NC}\n"
		exit 1
	fi
	echo ${opath} > .opath
	echo
elif [ -e .opath ]
then
	opath=$(cat .opath)
	echo -e "Output Directory: ${YLW}${opath}${NC}"
	echo -e "If you want to change directory, delete ${YLW}$PWD/.opath${NC} file\n"
else
	echo -e "\n${RED}ERROR: opath${NC}\n"
	exit 1
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
echo -e "\n${YLW}WARNING: Mandatory if today is not the broadcasting day${NC}"
echo -ne "Custom sleep timer before starting script (in seconds / Skip if you don't want) : "
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
	echo -e "${YLW}content folder does not exitst, creating...${NC}\n"
	mkdir "$opath"/content
else
	echo -e 'content folder exists\n'
fi
if [ ! -d "$opath"/log ]
then
	echo -e "${YLW}log folder does not exitst, creating...${NC}\n"
	mkdir "$opath"/log
else
	echo -e 'log folder exists\n'
fi
if [ ! -d "$opath"/show ]
then
	echo -e "${YLW}show folder does not exitst, creating...${NC}\n"
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
	if [ "$ctlength" -lt 2500 ] && [ "$lslength" -lt 1000 ]
	then
		ctretry=0
		echo -e "\n${YLW}content/livestatus 파일이 올바르지 않음, 1초 후 재시도${NC}"
		while :
		do
			((ctretry++))
			timer=1
			counter
			echo -e "재시도 횟수: $ctretry / 최대 재시도 횟수: $maxretry\n"
			ctlength=$(curl --head https://now.naver.com/api/nnow/v1/stream/$number/content | grep -oP 'content-length: \K[0-9]*')
			lslength=$(curl --head https://now.naver.com/api/nnow/v1/stream/$number/livestatus | grep -oP 'content-length: \K[0-9]*')
			echo -e "\nctlength: $ctlength / lslength: $lslength"
			if [ "$ctlength" -lt 2500 ] && [ "$lslength" -lt 1000 ]
			then
				if [ "$ctretry" -lt "$maxretry" ]
				then
					echo -e "\n${YLW}content/livestatus 파일이 올바르지 않음, 1초 후 재시도${NC}"
				elif [ "$ctretry" -ge "$maxretry" ]
				then
					echo -e "\n${RED}다운로드 실패\n최대 재시도 횟수($maxretry회) 도달, 스크립트 종료${NC}\n"
					exit 1
				else
					echo -e "\n${RED}ERROR: contentget(): ctretry,maxretry${NC}\n"
					exit 1
				fi
			elif [ "$ctlength" -ge 2500 ] && [ "$lslength" -ge 1000 ]
			then
				echo -e "\n${GRN}정상 content/livestatus 파일${NC}\n"
				wget -O "$opath"/content/"$date"_"$number".content https://now.naver.com/api/nnow/v1/stream/"$number"/content
				wget -O "$opath"/content/"$date"_"$number".livestatus https://now.naver.com/api/nnow/v1/stream/"$number"/livestatus
				break
			else
				echo -e "\n${RED}ERROR: contentget(): ctlength 1${NC}\n"
				exit 1
			fi
		done
		unset ctretry
	elif [ "$ctlength" -ge 2500 ] && [ "$lslength" -ge 1000 ]
	then
		echo -e "\n${GRN}정상 content/livestatus 파일${NC}\n"
		wget -O "$opath"/content/"$date"_"$number".content https://now.naver.com/api/nnow/v1/stream/"$number"/content
		wget -O "$opath"/content/"$date"_"$number".livestatus https://now.naver.com/api/nnow/v1/stream/"$number"/livestatus
		unset ctretry
	else
		echo -e "\n${RED}ERROR: contentget(): ctlength 2${NC}\n"
		exit 1
	fi
}

function getstream()
{
	echo '방송시간: '"$starttime"' / 현재: '"$hour"':'"$min"':'"$sec"
	if [ "$vcheck" = 'true' ]
	then
		echo -e "\n${YLW}보이는 쇼 입니다${NC}"
	fi
	echo -e "\n$title E$ep $subjects"
	echo -e "${filenames}.ts\n$url\n"
	#-ERROR-CHECK------------------------------------------------------
	youtube-dl "$url" --output "$opath"/show/"$title"/"$filenames".ts \
	& ypid="$!"
	
	echo -e "youtube-dl PID=${ypid}\n"
	wait ${ypid}
	pstatus="$?"

	echo -e "\nPID: ${ypid} / Exit code: ${pstatus}"
	#-ERROR-CHECK------------------------------------------------------
	if [ "$pstatus" != 0 ]
	then
		if [ "$maxretry" = 0 ]
		then
			echo -e "\n${RED}다운로드 실패, 스크립트 종료${NC}\n"
			exit 1
		fi
		if [ -n "$retry" ]
		then
			echo -e "\n재시도 횟수: $retry / 최대 재시도 횟수: $maxretry"
		fi
		if [ -z "$retry" ] || [ "$retry" -lt "$maxretry" ]
		then
			echo -e "\n${YLW}다운로드 실패, 재시도 합니다${NC}\n"
			((retry++))
		elif [ "$retry" -ge "$maxretry" ]
		then
			echo -e "\n${RED}다운로드 실패\n최대 재시도 횟수($maxretry회) 도달, 스크립트 종료${NC}\n"
			exit 1
		else
			echo -e "\n${RED}ERROR: getstream(): maxretry 1${NC}\n"
			exit 1
		fi
		contentget
		exrefresh
		timeupdate
		getstream
	elif [ "$pstatus" = 0 ]
	then
		if [ -z "$retry" ]
		then
			retry=0
		fi
		echo -e "\n${GRN}다운로드 성공${NC}"
		echo -e "\n총 재시도 횟수: $retry"
	else
		echo -e "\n${RED}youtube-dl: exit code $pstatus"
		echo -e "ERROR: gsretry()${NC}\n"
		exit 1
	fi
	unset retry ypid pstatus
	echo -e "\n${GRN}다운로드 완료, 3초 대기${NC}"
	timer=3
	counter
	ptime=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$opath"/show/"$title"/"$filenames".ts | grep -o '^[^.]*')
	echo -e "스트리밍 시간: $ptime초 / 스트리밍 정상 종료 기준: $ptimeth초"
	if [ "$ptime" -lt "$ptimeth" ]
	then
		if [ -z "$sfailcheck" ]
		then
			echo -e "\n${RED}스트리밍이 정상 종료되지 않음, 1분 후 재시작${NC}"
			sfailcheck=1
			timer=60
			counter
			contentget
			exrefresh
			timeupdate
			getstream
		elif [ -n "$sfailcheck" ]
		then
			echo -e "\n${GRN}스트리밍이 정상 종료됨${NC}"
			convert
		else
			echo -e "\n${RED}ERROR: sfailcheck${NC}\n"
			exit 1
		fi
	elif [ "$ptime" -ge "$ptimeth" ]
	then
		echo -e "\n${GRN}스트리밍이 정상 종료됨${NC}"
		convert
	else
		echo -e "\n${RED}ERROR: ptime/ptimeth${NC}\n"
		exit 1
	fi
}

function convert()
{
	codec=$(ffprobe -v error -show_streams -select_streams a "$opath"/show/"$title"/"$filenames".ts | grep -oP 'codec_name=\K[^+]*')
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
		echo -e "\n${RED}ERROR: : Unable to get codec info${NC}\n"
		exit 1
	fi
	echo -e "\n${GRN}Job Finished, Code: $sreason${NC}\n"
	exit 0
}

function exrefresh()
{
	#showhost=$(cat "$opath"/content/"$date"_"$number".content | grep -oP '"host":\["\K[^"]+')
	#enddate=$(cat "$opath"/content/"$date"_"$number".livestatus | grep -oP '"endDatetime":"20\K[^T]+')
	title=$(cat "$opath"/content/"$date"_"$number".content | grep -oP 'home":{"title":{"text":"\K[^"]+')
	vcheck=$(cat "$opath"/content/"$date"_"$number".content | grep -oP 'video":\K[^,]+')
	if [ "$vcheck" = 'true' ]
	then
		url=$(cat "$opath"/content/"$date"_"$number".livestatus | grep -oP 'videoStreamUrl":"\K[^"]+')
	else
		url=$(cat "$opath"/content/"$date"_"$number".livestatus | grep -oP 'liveStreamUrl":"\K[^"]+')
	fi
	startdate=$(cat "$opath"/content/"$date"_"$number".livestatus | grep -oP 'startDatetime":"20\K[^T]+')
	starttime=$(cat "$opath"/content/"$date"_"$number".livestatus | grep -oP 'startDatetime":"\K[^"]+' | grep -oP 'T\K[^.+]+')
	subject=$(cat "$opath"/content/"$date"_"$number".content | grep -oP '},"title":{"text":"\K[^"]+')
	ep=$(cat "$opath"/content/"$date"_"$number".content | grep -oP '"count":"\K[^회"]+')
	onair=$(cat "$opath"/content/"$date"_"$number".livestatus | grep -oP $number'","status":"\K[^"]+') # READY | END | ONAIR
	subjects=${subject//'\r\n'/}
	startdates=${startdate//'-'/}
	starttimes=${starttime//':'/}
	echo -e "${YLW}Exports refreshed${NC}\n"
}

function timeupdate()
{
	date=$(date +'%y%m%d')
	hour=$(date +'%H')
	min=$(date +'%M')
	sec=$(date +'%S')
	stimehr=$(expr substr "$starttimes" 1 2)
	stimemin=$(expr substr "$starttimes" 3 2)
	timecheck=$(echo "($stimehr*60+$stimemin)-($hour*60+$min)" | bc -l)
	filename="$date.NAVER NOW.$title.E$ep.${subjects}_$hour$min$sec"
	filenames=${filename//'/'/.}
	echo -e "${YLW}Time refreshed${NC}\n"
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

function onairwait()
{
	while :
	do
		echo -e '방송이 시작되지 않았습니다\n'
		timeupdate	
		echo -e 'Time difference: '"$timecheck"' min'
		counter
		echo -e 'content/livestatus 다시 불러오는 중...\n'
		contentget
		exrefresh
		timeupdate
		echo -e '방송일  : '"$startdates"' / 오늘: '"$date"
		echo '방송시간: '"$starttimes"' / 현재: '"$hour$min$sec"
		if [ "$vcheck" = 'true' ]
		then
			echo -e "\n${YLW}보이는 쇼 입니다${NC}"
		fi
		echo -e "\n$title E$ep $subjects\n$url\n"
		if [ "$timecheck" -ge 65 ]
		then
			timer=3600
		# 시작 시간이 65분 미만 차이
		elif [ "$timecheck" -lt 65 ]
		then
			# 시작 시간이 12분 초과 차이
			if [ "$timecheck" -gt 12 ]
			then
				timer=600
			# 시작 시간이 12분 이하 차이
			elif [ "$timecheck" -le 12 ]
			then
				# 시작 시간이 3분 초과 차이
				if [ "$timecheck" -gt 3 ]
				then
					timer=60
				# 시작 시간이 3분 이하 차이
				elif [ "$timecheck" -le 3 ]
				then
					timer=1
				else
					echo -e "\n${RED}ERROR: onairwait(): 1${NC}\n"
					exit 1
				fi
			else
				echo -e "\n${RED}ERROR: onairwait(): 2${NC}\n"
				exit 1
			fi
		else
			echo -e "\n${RED}ERROR: onairwait(): 3${NC}\n"
			exit 1
		fi
		# 방송 상태 확인
		if [ "$onair" = "READY" ] || [ "$onair" = "END" ]
		then
			echo -e "Live Status: ${YLW}$onair${NC}\n"
		elif [ "$onair" = "ONAIR" ]
		then
			echo -e "Live Status: ${GRN}$onair${NC}\n"
			echo -e "${GRN}content/livestatus 불러오기 완료${NC}\n3초 동안 대기 후 다운로드 합니다"
			timer=3
			counter
			contentget
			exrefresh
			timeupdate
			break
		elif [ -z "$onair" ]
		then
			echo -e "\n${YLW}WARNING: onairwait(): onair returned null"
			echo -e "Retrying...${NC}\n"
		else
			echo -e "\n${RED}Unknown Live Status: $onair"
			echo -e "ERROR: onairwait(): onair${NC}\n"
			exit 1
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
	echo -e "${YLW}비디오 스트림 발견, 함께 다운로드 합니다${NC}\n"
else
	echo -e "${YLW}비디오 스트림 없음, 오디오만 다운로드 합니다${NC}\n"
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
	echo -e "\n${RED}ERROR: custimer${NC}\n"
	exit 1
fi

if [ "$force" = "1" ] && [ -n "$number" ]
then
	echo -e "${YLW}Force Download Enabled!${NC}\n"
	sreason="-f"
	getstream
fi

if [ "$onair" = "READY" ] || [ "$onair" = "END" ]
then
	echo -e "Live Status: ${YLW}$onair${NC}\n"
	timer=0
	onairwait
	# 시작 시간이 됐을 경우
	if [ "$hour$min$sec" -ge "$starttimes" ]
	then
		echo -e "${GRN}쇼가 시작됨${NC}\n"
		sreason=1
		getstream
	# 시작 시간이 안됐을 경우
	elif [ "$hour$min$sec" -lt "$starttimes" ]
	then
		echo -e "${YLW}쇼가 아직 시작되지 않음${NC}\n"
		while :
		do
			echo '방송시간: '"$starttimes"' / 현재: '"$hour$min$sec"
			echo -e '\n대기 중...('"$hour$min$sec"')'
			sleep 1
			contentget
			exrefresh
			timeupdate
			# 시작 시간 확인
			if [ "$hour$min$sec" -ge "$starttimes" ]
			then
				echo '방송시간: '"$starttimes"' / 현재: '"$hour$min$sec"
				echo -e "${GRN}쇼가 시작됨${NC}\n"
				break
			fi
		done
		sreason=2
		getstream
	else
		echo -e "\n${RED}ERROR: 1${NC}\n"
		exit 1
	fi
elif [ "$onair" = "ONAIR" ]
then
	echo -e "Live Status: ${GRN}$onair${NC}\n"
	echo -e "${GRN}쇼가 시작됨${NC}\n"
	sreason=3
	getstream
else
	echo -e "${RED}ERROR: 2${NC}\n"
	exit 1
fi

echo -e "${RED}ERROR: EOF${NC}\n"
exit 2
