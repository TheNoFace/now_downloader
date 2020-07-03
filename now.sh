#!/bin/bash

#------------------------------------------------------------------
#
# Now Downloader
#
# Created on 2020 May 12
# Updated on 2020 July 3
#
# Author: TheNoFace (thenoface303@gmail.com)
#
# Version 1.0.3
#
# TODO:
# 200531-1) 방송 시각과 현재 시각 차이가 20분 이상이면 (시각차이-20)분 sleep
# 200531-2) ERROR CHECK에 $vcheck = true일 경우 오디오/비디오 스트림 동시에 받기
#
#------------------------------------------------------------------

# contentget -> exrefresh -> timeupdate

# Color template: echo -e "${RED}TITLE${GRN}MESSAGE${NC}"
RED='\033[0;31m' # Error or force exit
YLW='\033[1;33m' # Warning or alert
GRN='\033[0;32m'
NC='\033[0m' # No Color

NDV="1.0.3"
BANNER="\nNow Downloader v$NDV\n"
SCRIPT_NAME=$(basename $0)
STMSG=("\n---SCRIPT-START------------------------------------------$(date +'%F %a %T')---\n")

SHOW_ID=""
FORCE=""
OPATH_I=""
MAXRETRY=""
N_RETRY=""
PTIMETH=""
N_PTIMETH=""
CUSTIMER=""
SREASON=""

### VALIDATOR

function is_not_empty()
{
	[ -z "$1" ] && return 1
	return 0
}

function is_empty()
{
	[ -z "$1" ] && return 0
	return 1
}

### MESSAGES

function err_msg()
{
	if is_not_empty "$1"
	then
		echo -e "${RED}$1${NC}"
	fi
}

function alert_msg()
{
	if is_not_empty "$1"
	then
		echo -e "${YLW}$1${NC}"
	fi
}

function info_msg()
{
	if is_not_empty "$1"
	then
		echo -e "${GRN}$1${NC}"
	fi
}

function msg()
{
	if is_not_empty "$1"
	then
		echo -e "$1"
	fi
}

### FUNCTION STARTS

function get_parms()
{
	while :
	do
		case "$1" in
			-v|--version|-version)
				print_banner ; exit 0 ;;
			-h|--help|-help)
				print_help ; exit 0 ;;
			-i|-id|--id)
				SHOW_ID="$2" ; shift ; shift ;;
			-f|--force)
				FORCE=1 ; shift ;;
			-o|--opath)
				OPATH_I="$2" ; shift ; shift ;;
			-r|--maxretry)
				MAXRETRY="$2" ; shift ; shift ;;
			-dr|--dretry)
				N_RETRY=1 ; shift ;;
			-t|--ptimeth)
				PTIMETH="$2" ; shift ; shift ;;
			-dt|--dptime)
				N_PTIMETH=1 ; shift ;;
			-c|--custimer)
				CUSTIMER="$2" ; shift ; shift ;;
			*)
				check_invalid_parms "$1" ; break ;;
		esac
	done
}

function check_invalid_parms()
{
	if is_not_empty "$1"
	then
		print_banner
		err_msg "Invalid Option: $1\n"
		exit 2
	elif [ -z ${SHOW_ID} ]
	then
		print_banner
		err_msg "Please enter valid Show ID\n"
		exit 2
	fi
	return 0
}

function print_banner()
{
	info_msg "$BANNER"
}

function print_help()
{
	print_banner
	echo -e "Usage: $SCRIPT_NAME -i [ShowID] [options]\n"

	alert_msg Required:
	echo "  -i  | --id [number]         ID of the show to download

Options:
  -v  | --version             Show program name and version
  -h  | --help                Show this help screen
  -f  | --force               Start download immediately without any time checks
  -o  | --opath <dir>         Overrides output path to check if it's been set before
  -r  | --maxretry [number]   Maximum retries if download fails
                              Default is set to 10 (times)
  -dr | --dretry              Disable retries
  -t  | --ptimeth [seconds]   Failcheck threshold if the stream has ended abnormally
                              Default is set to 3300 (seconds)
  -dt | --dptime              Disable failcheck threshold
  -c  | --custimer [seconds]  Custom sleep timer before starting script"
	alert_msg "                              WARNING: Mandatory if today is not the broadcasting day"

	echo "Notes:
  - Short options should not be grouped. You must pass each parameter on its own.
  - Disabling flags priors than setting flags

Example:
* $SCRIPT_NAME -i 495 -f -o /home/$USER/now -r 100 -t 3000 -c 86400
  - Override output directory to /home/$USER/now
  - Wait 86400 seconds (24hr) before starting this script
  - Download #495 show
  - Retries 100 times if download fails
  - Retries if total stream time is less than 3000 seconds
* $SCRIPT_NAME -i 495 -f -dr -dt -f
  - Do not retry download even if download fails
  - Do not check stream duration
  - Download #495 show immediately without checking time
"
}

function dir_check()
{
	if [ ! -d "${OPATH}" ]
	then
		mkdir -p "${OPATH}" & mdpid="$!"
		wait ${mdpid}
		pstatus="$?"

		if [ $pstatus != 0 ]
		then
			err_msg "\nERROR: Couldn't create directory\nAre you sure you have proper ownership?\n"
			exit 1
		fi

		info_msg "\nCreated Output Directory: ${OPATH}"
		unset pstatus
	fi
	echo ${OPATH} > .opath
	echo
}

function script_init()
{
	echo -e ${STMSG}
	if [ -n "$FORCE" ]
	then
		alert_msg "Force Download Enabled!"
	fi
	
	if [ "$N_RETRY" = "1" ]
	then
		MAXRETRY=0
		alert_msg "Retry Disabled!"
	fi

	if [ "$N_PTIMETH" = "1" ]
	then
		alert_msg "Stream duration check Disabled!"
	fi

	if [ -z "$CUSTIMER" ]
	then
		alert_msg "Custom timer before start Disabled!"
	fi

	if [ -z ${OPATH_I} ]
	then
		if [ ! -e .opath ]
		then
			echo -e "\nSeems like it's your first time to run this scipt"
			echo -n "Please enter directory to save (e.g: /home/$USER/now): "
			read OPATH
			OPATH=${OPATH/"~"/"/home/$USER"}
			dir_check
		elif [ -e .opath ]
		then
			OPATH=$(cat .opath)
			echo -e "\nOutput Path: ${YLW}${OPATH}${NC}"
			echo -e "If you want to change output path, delete ${YLW}$PWD/.opath${NC} file or use -o option\n"
		else
			err_msg "\nERROR: script_init OPATH\n"
			exit 1
		fi
	elif [ -n ${OPATH_I} ]
	then
		OPATH=${OPATH_I/"~"/"/home/$USER"}
		echo -e "\nOutput Path: ${YLW}${OPATH} (Overrided)${NC}"
		dir_check
	fi

	for i in content log show
	do
		if [ ! -d "${OPATH}/$i" ]
		then
			alert_msg "$i folder does not exitst, creating..."
			mkdir "${OPATH}/$i"
		else
			msg "$i folder exists"
		fi
	done
	echo

	if [ -z "$N_RETRY" ]
	then
		if [ -z "$MAXRETRY" ]
		then
			MAXRETRY="10"
			alert_msg "Maximum retry set to default ($MAXRETRY times)"
		else
			alert_msg "Maximum retry set to $MAXRETRY times"
		fi
	fi

	if [ -z "$N_PTIMETH" ]
	then
		if [ -z "$PTIMETH" ]
		then
			PTIMETH="3300"
			alert_msg "Failcheck threshold set to default (${PTIMETH}s)"
		else
			alert_msg "Failcheck threshold set to ${PTIMETH}s"
		fi
	fi

	if [ -n "$CUSTIMER" ]
	then
		alert_msg "Custom sleep timer set to ${CUSTIMER}s"
	fi

	if [ -z "$N_RETRY" ] || [ -z "$N_PTIMETH" ] || [ -n "$CUSTIMER" ]
	then
		echo
	fi
}

# content: general information of show
# livestatus: audio/video stream information of show
function contentget()
{
	ctlength=$(curl --head https://now.naver.com/api/nnow/v1/stream/${SHOW_ID}/content | grep -oP 'content-length: \K[0-9]*')
	lslength=$(curl --head https://now.naver.com/api/nnow/v1/stream/${SHOW_ID}/livestatus | grep -oP 'content-length: \K[0-9]*')
	msg "\nctlength: $ctlength / lslength: $lslength"
	if [ "$ctlength" -lt 2500 ] && [ "$lslength" -lt 1000 ]
	then
		ctretry=0
		alert_msg "\ncontent/livestatus 파일이 올바르지 않음, 1초 후 재시도"
		while :
		do
			((ctretry++))
			timer=1
			counter
			echo -e "재시도 횟수: $ctretry / 최대 재시도 횟수: $MAXRETRY\n"
			ctlength=$(curl --head https://now.naver.com/api/nnow/v1/stream/${SHOW_ID}/content | grep -oP 'content-length: \K[0-9]*')
			lslength=$(curl --head https://now.naver.com/api/nnow/v1/stream/${SHOW_ID}/livestatus | grep -oP 'content-length: \K[0-9]*')
			echo -e "\nctlength: $ctlength / lslength: $lslength"
			if [ "$ctlength" -lt 2500 ] && [ "$lslength" -lt 1000 ]
			then
				if [ "$ctretry" -lt "$MAXRETRY" ]
				then
					alert_msg "\ncontent/livestatus 파일이 올바르지 않음, 1초 후 재시도"
				elif [ "$ctretry" -ge "$MAXRETRY" ]
				then
					err_msg "\n다운로드 실패\n최대 재시도 횟수($MAXRETRY회) 도달, 스크립트 종료\n"
					exit 1
				else
					err_msg "\nERROR: contentget(): ctretry,MAXRETRY\n"
					exit 1
				fi
			elif [ "$ctlength" -ge 2500 ] && [ "$lslength" -ge 1000 ]
			then
				info_msg "\n정상 content/livestatus 파일\n"
				wget -O "${OPATH}/content/${d_date}_${SHOW_ID}".content https://now.naver.com/api/nnow/v1/stream/${SHOW_ID}/content
				wget -O "${OPATH}/content/${d_date}_${SHOW_ID}".livestatus https://now.naver.com/api/nnow/v1/stream/${SHOW_ID}/livestatus
				break
			else
				err_msg "\nERROR: contentget(): ctlength 1\n"
				exit 1
			fi
		done
		unset ctretry
	elif [ "$ctlength" -ge 2500 ] && [ "$lslength" -ge 1000 ]
	then
		info_msg "\n정상 content/livestatus 파일\n"
		wget -O "${OPATH}/content/${d_date}_${SHOW_ID}".content https://now.naver.com/api/nnow/v1/stream/${SHOW_ID}/content
		wget -O "${OPATH}/content/${d_date}_${SHOW_ID}".livestatus https://now.naver.com/api/nnow/v1/stream/${SHOW_ID}/livestatus
		unset ctretry
	else
		err_msg "\nERROR: contentget(): ctlength 2\n"
		exit 1
	fi
}

function getstream()
{
	echo '방송시간: '"$starttime"' / 현재: '"$hour"':'"$min"':'"$sec"
	if [ "$vcheck" = 'true' ]
	then
		alert_msg "\n보이는 쇼 입니다"
	fi
	echo -e "\n$title E$ep $subject"
	echo -e "${filename}.ts\n$url\n"
	#-ERROR-CHECK------------------------------------------------------
	youtube-dl "$url" --output "${OPATH}/show/$title/$filename".ts \
	& ypid="$!"
	
	echo -e "youtube-dl PID=${ypid}\n"
	wait ${ypid}
	pstatus="$?"

	echo -e "\nPID: ${ypid} / Exit code: ${pstatus}"
	#-ERROR-CHECK------------------------------------------------------
	if [ "$pstatus" != 0 ]
	then
		if [ "$MAXRETRY" = 0 ]
		then
			err_msg "\n다운로드 실패, 스크립트 종료\n"
			exit 1
		fi
		if [ -n "$retry" ]
		then
			echo -e "\n재시도 횟수: $retry / 최대 재시도 횟수: $MAXRETRY"
		fi
		if [ -z "$retry" ] || [ "$retry" -lt "$MAXRETRY" ]
		then
			alert_msg "\n다운로드 실패, 재시도 합니다\n"
			((retry++))
		elif [ "$retry" -ge "$MAXRETRY" ]
		then
			err_msg "\n다운로드 실패\n최대 재시도 횟수($MAXRETRY회) 도달, 스크립트 종료\n"
			exit 1
		else
			err_msg "\nERROR: getstream(): MAXRETRY 1\n"
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
		info_msg "\n다운로드 성공"
		echo -e "\n총 재시도 횟수: $retry"
	else
		err_msg "\nyoutube-dl: exit code $pstatus"
		err_msg "ERROR: gsretry()\n"
		exit 1
	fi
	unset retry ypid pstatus
	info_msg "\n다운로드 완료, 3초 대기"
	timer=3
	counter

	if [ "$N_PTIMETH" = "1" ]
	then
		alert_msg "스트리밍 길이를 확인하지 않습니다"
	else
		ptime=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "${OPATH}/show/$title/$filename.ts" | grep -o '^[^.]*')
		echo -e "스트리밍 시간: $ptime초 / 스트리밍 정상 종료 기준: $PTIMETH초"
		if [ "$ptime" -lt "$PTIMETH" ]
		then
			if [ -z "$sfailcheck" ]
			then
				err_msg "\n스트리밍이 정상 종료되지 않음, 1분 후 재시작"
				sfailcheck=1
				timer=60
				counter
				contentget
				exrefresh
				timeupdate
				getstream
			elif [ -n "$sfailcheck" ]
			then
				info_msg "\n스트리밍이 정상 종료됨"
				convert
			else
				err_msg "\nERROR: sfailcheck\n"
				exit 1
			fi
		elif [ "$ptime" -ge "$PTIMETH" ]
		then
			info_msg "\n스트리밍이 정상 종료됨"
			convert
		else
			err_msg "\nERROR: ptime/PTIMETH\n"
			exit 1
		fi
	fi
}

function convert()
{
	codec=$(ffprobe -v error -show_streams -select_streams a "${OPATH}/show/$title/$filename.ts" | grep -oP 'codec_name=\K[^+]*')
	if [ "$codec" = 'mp3' ]
	then 
		msg "\nCodec: MP3, Saving into mp3 file\n"
		ffmpeg -i "${OPATH}/show/$title/$filename.ts" -vn -c:a copy "${OPATH}/show/$title/$filename.mp3"
		msg "\nConvert Complete: $filename.mp3"
	elif [ "$codec" = 'aac' ]
	then
		msg "\nCodec: AAC, Saving into m4a file\n"
		ffmpeg -i "${OPATH}/show/$title/$filename.ts" -vn -c:a copy "${OPATH}/show/$title/$filename.m4a"
		msg "\nConvert Complete: $filename.m4a"
	else
		err_msg "\nERROR: : Unable to get codec info\n"
		exit 1
	fi
	info_msg "\nJob Finished, Code: $SREASON\n"
	exit 0
}

function exrefresh()
{
	#showhost=$(cat "${OPATH}/content/${d_date}_${SHOW_ID}.content" | grep -oP '"host":\["\K[^"]+')
	#enddate=$(cat "${OPATH}/content/${d_date}_${SHOW_ID}.livestatus" | grep -oP '"endDatetime":"20\K[^T]+')
	title=$(cat "${OPATH}/content/${d_date}_${SHOW_ID}.content" | grep -oP 'home":{"title":{"text":"\K[^"]+')
	vcheck=$(cat "${OPATH}/content/${d_date}_${SHOW_ID}.content" | grep -oP 'video":\K[^,]+')
	if [ "$vcheck" = 'true' ]
	then
		url=$(cat "${OPATH}/content/${d_date}_${SHOW_ID}.livestatus" | grep -oP 'videoStreamUrl":"\K[^"]+')
	else
		url=$(cat "${OPATH}/content/${d_date}_${SHOW_ID}.livestatus" | grep -oP 'liveStreamUrl":"\K[^"]+')
	fi
	startdate=$(cat "${OPATH}/content/${d_date}_${SHOW_ID}.livestatus" | grep -oP 'startDatetime":"20\K[^T]+')
	starttime=$(cat "${OPATH}/content/${d_date}_${SHOW_ID}.livestatus" | grep -oP 'startDatetime":"\K[^"]+' | grep -oP 'T\K[^.+]+')
	subject=$(cat "${OPATH}/content/${d_date}_${SHOW_ID}.content" | grep -oP '},"title":{"text":"\K[^"]+')
	ep=$(cat "${OPATH}/content/${d_date}_${SHOW_ID}.content" | grep -oP '"count":"\K[^회"]+')
	onair=$(cat "${OPATH}/content/${d_date}_${SHOW_ID}.livestatus" | grep -oP ${SHOW_ID}'","status":"\K[^"]+') # READY | END | ONAIR
	subject=${subject//'\r\n'/' '}
	startdate=${startdate//'-'/}
	starttime=${starttime//':'/}
	alert_msg "Exports refreshed\n"
}

function timeupdate()
{
	d_date=$(date +'%y%m%d')
	hour=$(date +'%H')
	min=$(date +'%M')
	sec=$(date +'%S')
	stimehr=$(expr substr "$starttime" 1 2)
	stimemin=$(expr substr "$starttime" 3 2)
	timecheck=$(echo "($stimehr*60+$stimemin)-($hour*60+$min)" | bc -l)
	filename="${d_date}.NAVER NOW.$title.E$ep.${subject}_$hour$min$sec"
	filename=${filename//'/'/' '}
	alert_msg "Time refreshed\n"
}

function counter()
{
	if [ "$timer" -gt 0 ]
	then
		echo -e '\n총 '"$timer"'초 동안 대기합니다'
		while [ "$timer" -gt 0 ]
		do
			echo -ne "$timer\033[0K"'초 남음'"\r"
			sleep 1
			((timer--))
		done
		echo -e '\n'
	fi
	unset timer
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
		echo -e '방송일  : '"$startdate"' / 오늘: '"${d_date}"
		echo '방송시간: '"$starttime"' / 현재: '"$hour$min$sec"
		if [ "$vcheck" = 'true' ]
		then
			alert_msg "\n보이는 쇼 입니다"
		fi
		echo -e "\n$title E$ep $subject\n$url\n"
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
					err_msg "\nERROR: onairwait(): 1\n"
					exit 1
				fi
			else
				err_msg "\nERROR: onairwait(): 2\n"
				exit 1
			fi
		else
			err_msg "\nERROR: onairwait(): 3\n"
			exit 1
		fi
		# 방송 상태 확인
		if [ "$onair" != "ONAIR" ]
		then
			echo -e "Live Status: ${YLW}$onair${NC}\n"
		elif [ "$onair" = "ONAIR" ]
		then
			echo -e "Live Status: ${GRN}$onair${NC}\n"
			info_msg "content/livestatus 불러오기 완료\n"
			msg "3초 동안 대기 후 다운로드 합니다"
			timer=3
			counter
			contentget
			exrefresh
			timeupdate
			break
		elif [ -z "$onair" ]
		then
			alert_msg "\nWARNING: onairwait(): onair returned null"
			alert_msg "Retrying...\n"
		else
			err_msg "\nUnknown Live Status: $onair"
			err_msg "ERROR: onairwait(): onair\n"
			exit 1
		fi
	done
}

function main()
{
	d_date=$(date +'%y%m%d')
	contentget
	exrefresh
	timeupdate

	if [ "$vcheck" = 'true' ]
	then
		alert_msg "비디오 스트림 발견, 함께 다운로드 합니다\n"
	else
		alert_msg "비디오 스트림 없음, 오디오만 다운로드 합니다\n"
	fi

	echo "방송일  : $startdate / 오늘: ${d_date}"
	echo -e "방송시간: $starttime / 현재: $hour$min$sec"
	echo -e "$title E$ep $subject\n"

	if [ -n "$CUSTIMER" ]
	then
		alert_msg "사용자가 설정한 시작 대기 타이머가 존재합니다 ($CUSTIMER초)"
		timer=$CUSTIMER
		counter
		contentget
		exrefresh
		timeupdate
	elif [ -z "$CUSTIMER" ]
	then
		echo -e "사용자가 설정한 시작 대기 타이머가 없음\n"
		contentget
		exrefresh
		timeupdate
	else
		err_msg "\nERROR: CUSTIMER\n"
		exit 1
	fi

	if [ -n "$FORCE" ]
	then
		SREASON="FORCE"
		getstream
	fi

	if [ "$onair" != "ONAIR" ]
	then
		echo -e "Live Status: ${YLW}$onair${NC}\n"
		timer=0
		onairwait
		# 시작 시간이 됐을 경우
		if [ "$hour$min$sec" -ge "$starttime" ]
		then
			info_msg "쇼가 시작됨\n"
			SREASON=1
			getstream
		# 시작 시간이 안됐을 경우
		elif [ "$hour$min$sec" -lt "$starttime" ]
		then
			alert_msg "쇼가 아직 시작되지 않음\n"
			while :
			do
				echo '방송시간: '"$starttime"' / 현재: '"$hour$min$sec"
				echo -e '\n대기 중...('"$hour$min$sec"')'
				sleep 1
				contentget
				exrefresh
				timeupdate
				# 시작 시간 확인
				if [ "$hour$min$sec" -ge "$starttime" ]
				then
					echo '방송시간: '"$starttime"' / 현재: '"$hour$min$sec"
					info_msg "쇼가 시작됨\n"
					break
				fi
			done
			SREASON=2
			getstream
		else
			err_msg "\nERROR: 1\n"
			exit 1
		fi
	elif [ "$onair" = "ONAIR" ]
	then
		echo -e "Live Status: ${GRN}$onair${NC}\n"
		info_msg "쇼가 시작됨\n"
		SREASON=3
		getstream
	else
		err_msg "ERROR: 2\n"
		exit 1
	fi
}

### SCRIPT START
				
get_parms "$@"
script_init
main

err_msg "ERROR: EOF\n"
exit 10