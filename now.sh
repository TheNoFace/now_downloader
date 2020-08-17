#!/bin/bash

#------------------------------------------------------------------
#
# Now Downloader
#
# Created on 2020 May 12
# Updated on 2020 August 12
#
# Author: TheNoFace (thenoface303@gmail.com)
#
# TODO:
# 200531) 방송 시각과 현재 시각 차이가 20분 이상이면 (시각차이-20)분 sleep
# 200812) 방송 요일 구해서 금일 방송이 아니라면 자동 custimer
# 200812) contentget에서 curl 삭제, wget으로 파일 받은 후 크기 비교, 이상 시 다시 받기
#
#------------------------------------------------------------------

# get_options -> script_init -> main
# contentget -> exrefresh -> timeupdate
# onairwait -> getstream -> convert

# Color template
if [ -t 1 ]
then
	RED=$(tput setaf 1)
	GRN=$(tput setaf 2)
	YLW=$(tput setaf 3)
	NC=$(tput sgr0)
else
	RED=""
	GRN=""
	YLW=""
	NC=""
fi

NDV="1.2.1"
BANNER="Now Downloader v$NDV"
SCRIPT_NAME=$(basename $0)

P_LIST=(bc curl jq youtube-dl ffmpeg)
P_LIST_E=0

SHOW_ID=""
FORCE=""
KEEP=""
OPATH_I=""
D_CHECK=""
MAXRETRY=""
N_RETRY=""
PTIMETH=""
N_PTIMETH=""
CUSTIMER=""
SREASON=""
VERB=""

CTRETRY="0"
RETRY="0"
EXRETRY="0"

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
			-k|--keep)
				KEEP=1 ; shift ;;
			-o|--opath)
				OPATH_I="$2" ; shift ; shift ;;
			-dc|--dcont)
				D_CHECK=1 ; shift ;;
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
			-vb|--verbose)
				VERB=1 ; shift ;;
			-u|--user)
				G_USR=1 ; shift ;;
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
	info_msg "\n$BANNER\n"
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
  -u  | --user                Display current/total users of the show
  -vb | --verbose             Display various information (curl/wget)
  -f  | --force               Start download immediately without any time checks
  -k  | --keep                Do not delete original audio stream(.ts) file after download finishes
  -o  | --opath <dir>         Overrides output path to check if it's been set before
  -dc | --dcont               Do not check integrity of content/livestatus files in content folder
  -r  | --maxretry [number]   Maximum retries if download fails
                              Default is set to 10 (times)
  -dr | --dretry              Disable retries (same as -r 0)
  -t  | --ptimeth [seconds]   Failcheck threshold if the stream has ended abnormally
                              Default is set to 3300 (seconds)
  -dt | --dptime              Disable failcheck threshold
  -c  | --custimer [seconds]  Custom sleep timer before starting script"
	alert_msg "                              WARNING: Mandatory if today is not the broadcasting day"

	echo "Notes:
  - Short options should not be grouped. You must pass each parameter on its own.
  - Disabling flags priors than setting flags

Example:
* $SCRIPT_NAME -i 495 -o /home/$USER/now -r 100 -t 3000 -c 86400
  - Override output directory to /home/$USER/now
  - Wait 86400 seconds (24hr) before starting this script
  - Download #495 show
  - Retries 100 times if download fails
  - Retries if total stream time is less than 3000 seconds
* $SCRIPT_NAME -i 495 -f -dr -dt -k
  - Do not retry download even if download fails
  - Do not check stream duration
  - Download #495 show immediately without checking time
  - Do not delete original audio stream file after download finishes
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
	d_date=$(date +'%y%m%d')

	for l in ${P_LIST[@]}
	{
		P=$(command -v $l)
		if [ -z $P ]
		then
			NFOUND=(${NFOUND[@]} $l)
			P_LIST_E=1
		fi
	}

	if [ $P_LIST_E == 1 ]
	then
		print_banner
		array=${NFOUND[@]}
		err_msg "Couldn't find follow package(s): $array"
		err_msg "Please install required package(s)\n"
		exit 1
	else
		if [ -t 1 ]
		then
			info_msg "\nPackage check OK!\n"
		else
			msg "\n---$BANNER-----------ShowID: ${SHOW_ID}-----------$(date +'%F %a %T')---"
			info_msg "\nPackage check OK!\n"
		fi
	fi

	if [ -n "$VERB" ]
	then
		alert_msg "Verbose Mode"
		curl_c="curl"
		wget_c="wget"
	else
		curl_c="curl --no-progress-meter"
		wget_c="wget -q"
	fi

	if [ -n "$FORCE" ]
	then
		alert_msg "Force Download Enabled"
	fi

	if [ -n "$KEEP" ]
	then
		alert_msg "Keep original audio stream file after download has finished"
	fi

	if [ -n "$N_RETRY" ]
	then
		MAXRETRY=0
		alert_msg "Retry Disabled"
	fi

	if [ -n "$N_PTIMETH" ]
	then
		alert_msg "Stream duration check Disabled"
	fi

	if [ -z "$CUSTIMER" ]
	then
		alert_msg "Custom timer before start is not set"
	fi

	if [ -n "$D_CHECK" ]
	then
		alert_msg "Do not check integrity of content/livestatus files in content folder"
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
		echo # For better logging
	fi

	if [ -n "$G_USR" ]
	then
		contentget
		exrefresh
		cur_user=$(cat "${OPATH}/content/${SHOW_ID}_${d_date}.livestatus" | grep -oP 'concurrentUserCount":\K[^,]+')
		total_user=$(cat "${OPATH}/content/${SHOW_ID}_${d_date}.livestatus" | grep -oP 'cumulativeUserCount":\K[^}]+')

		msg "\n$startdate $title by $showhost\n$subject"
		if [ "$onair" = "ONAIR" ]
		then
			msg "접속자 수: $cur_user / 총 조회수: $total_user\n"
		else
			msg "총 조회수: $total_user\n"
		fi
		exit 0
	fi
}

# content: general information of show
# livestatus: audio/video stream information of show
function contentget()
{
	if [ -z $D_CHECK ]
	then
		ctlength=$($curl_c --retry ${MAXRETRY} --retry-connrefused --head https://now.naver.com/api/nnow/v1/stream/${SHOW_ID}/content | grep -oP 'content-length: \K[0-9]*')
		lslength=$($curl_c --retry ${MAXRETRY} --retry-connrefused --head https://now.naver.com/api/nnow/v1/stream/${SHOW_ID}/livestatus | grep -oP 'content-length: \K[0-9]*')
		msg "content: $ctlength Bytes / livestatus: $lslength Bytes"
		if [ "$ctlength" -lt 2500 ] && [ "$lslength" -lt 1000 ]
		then
			alert_msg "\ncontent/livestatus 파일이 올바르지 않음, 1초 후 재시도"
			while :
			do
				((CTRETRY++))
				counter 1
				echo -e "재시도 횟수: $CTRETRY / 최대 재시도 횟수: $MAXRETRY\n"
				ctlength=$($curl_c --retry ${MAXRETRY} --retry-connrefused --head https://now.naver.com/api/nnow/v1/stream/${SHOW_ID}/content | grep -oP 'content-length: \K[0-9]*')
				lslength=$($curl_c --retry ${MAXRETRY} --retry-connrefused --head https://now.naver.com/api/nnow/v1/stream/${SHOW_ID}/livestatus | grep -oP 'content-length: \K[0-9]*')
				msg "content: $ctlength Bytes / livestatus: $lslength Bytes"
				if [ "$ctlength" -lt 2500 ] && [ "$lslength" -lt 1000 ]
				then
					if [ "$CTRETRY" -lt "$MAXRETRY" ]
					then
						alert_msg "\ncontent/livestatus 파일이 올바르지 않음, 1초 후 재시도"
					elif [ "$CTRETRY" -ge "$MAXRETRY" ]
					then
						err_msg "\n다운로드 실패\n최대 재시도 횟수($MAXRETRY회) 도달, 스크립트 종료\n"
						exit 1
					else
						err_msg "\nERROR: contentget(): CTRETRY,MAXRETRY\n"
						exit 1
					fi
				elif [ "$ctlength" -ge 2500 ] && [ "$lslength" -ge 1000 ]
				then
					info_msg "정상 content/livestatus 파일\n"
					$wget_c -O "${OPATH}/content/${SHOW_ID}_${d_date}.content" https://now.naver.com/api/nnow/v1/stream/${SHOW_ID}/content
					$wget_c -O "${OPATH}/content/${SHOW_ID}_${d_date}.livestatus" https://now.naver.com/api/nnow/v1/stream/${SHOW_ID}/livestatus
					break
				else
					err_msg "\nERROR: contentget(): ctlength 1\n"
					exit 1
				fi
			done
		elif [ "$ctlength" -ge 2500 ] && [ "$lslength" -ge 1000 ]
		then
			info_msg "정상 content/livestatus 파일\n"
			$wget_c -O "${OPATH}/content/${SHOW_ID}_${d_date}.content" https://now.naver.com/api/nnow/v1/stream/${SHOW_ID}/content
			$wget_c -O "${OPATH}/content/${SHOW_ID}_${d_date}.livestatus" https://now.naver.com/api/nnow/v1/stream/${SHOW_ID}/livestatus
		else
			err_msg "\nERROR: contentget(): ctlength 2\n"
			exit 1
		fi
		CTRETRY=0
	else
		$wget_c -O "${OPATH}/content/${SHOW_ID}_${d_date}.content" https://now.naver.com/api/nnow/v1/stream/${SHOW_ID}/content
		$wget_c -O "${OPATH}/content/${SHOW_ID}_${d_date}.livestatus" https://now.naver.com/api/nnow/v1/stream/${SHOW_ID}/livestatus
	fi
}

function content_backup()
{
	mv "${OPATH}/content/${SHOW_ID}_${d_date}.content" "${OPATH}/content/${SHOW_ID}_${d_date}.content.bak"
	mv "${OPATH}/content/${SHOW_ID}_${d_date}.livestatus" "${OPATH}/content/${SHOW_ID}_${d_date}.livestatus.bak"
}

function getstream()
{
	echo "방송시간: $starttime / 현재: $hour$min$sec"
	if [ "$vcheck" = 'true' ]
	then
		alert_msg "\n보이는 쇼 입니다"
	fi
	echo -e "\n$title E$ep $subject"
	echo -e "${FILENAME}.ts\n$url\n"
	#-ERROR-CHECK------------------------------------------------------
	youtube-dl --hls-use-mpegts "$url" --output "${OPATH}/show/$title/${FILENAME}.ts" \
	& ypid="$!"
	
	echo -e "youtube-dl PID=${ypid}\n"
	wait ${ypid}
	pstatus="$?"

	echo -e "\nPID: ${ypid} / Exit code: ${pstatus}"
	#-ERROR-CHECK------------------------------------------------------
	if [ "$pstatus" != 0 ]
	then
		if [ "$MAXRETRY" = "0" ]
		then
			err_msg "\ngetstream(): 다운로드 실패, 스크립트 종료\n"
			exit 1
		fi
		if [ "$RETRY" != "0" ]
		then
			echo -e "\n재시도 횟수: $RETRY / 최대 재시도 횟수: $MAXRETRY"
		fi
		if [ -z "$RETRY" ] || [ "$RETRY" -lt "$MAXRETRY" ]
		then
			alert_msg "\n다운로드 실패, 재시도 합니다\n"
			((RETRY++))
		elif [ "$RETRY" -ge "$MAXRETRY" ]
		then
			err_msg "\ngetstream(): 다운로드 실패\n최대 재시도 횟수($MAXRETRY회) 도달, 스크립트 종료\n"
			exit 1
		else
			err_msg "\nERROR: getstream(): MAXRETRY\n"
			exit 1
		fi
		contentget
		exrefresh
		timeupdate
		getstream
	elif [ "$pstatus" = 0 ]
	then
		if [ -z "$RETRY" ]
		then
			RETRY=0
		fi
		info_msg "\n다운로드 성공"
		echo -e "\n총 재시도 횟수: $RETRY"
	else
		err_msg "\nyoutube-dl: exit code $pstatus"
		err_msg "ERROR: gsretry()\n"
		exit 1
	fi
	unset ypid pstatus
	RETRY=0
	info_msg "\n다운로드 완료, 3초 대기"
	counter 3

	if [ -n "$N_PTIMETH" ]
	then
		alert_msg "스트리밍 길이를 확인하지 않습니다"
		convert
	else
		ptime=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "${OPATH}/show/$title/${FILENAME}.ts" | grep -o '^[^.]*')
		echo -e "스트리밍 시간: $ptime초 / 스트리밍 정상 종료 기준: $PTIMETH초"
		if [ "$ptime" -lt "$PTIMETH" ]
		then
			if [ -z "$sfailcheck" ]
			then
				err_msg "\n스트리밍이 정상 종료되지 않음, 1분 후 재시작"
				sfailcheck=1
				counter 60
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
	if [ "$vcheck" = 'true' ]
	then
		alert_msg "\n보이는 쇼 입니다\n"
	fi
	codec=$(ffprobe -v error -show_streams -select_streams a "${OPATH}/show/$title/${FILENAME}.ts" | grep -oP 'codec_name=\K[^+]*')
	if [ "$codec" = 'mp3' ]
	then 
		msg "\nCodec: MP3, Saving into mp3 file\n"
		ffmpeg -i "${OPATH}/show/$title/${FILENAME}.ts" -vn -c:a copy "${OPATH}/show/$title/${FILENAME}.mp3"
		msg "\nConvert Complete: ${FILENAME}.mp3"
	elif [ "$codec" = 'aac' ]
	then
		msg "\nCodec: AAC, Saving into m4a file\n"
		ffmpeg -i "${OPATH}/show/$title/${FILENAME}.ts" -vn -c:a copy "${OPATH}/show/$title/${FILENAME}.m4a"
		msg "\nConvert Complete: ${FILENAME}.m4a"
	else
		err_msg "\nERROR: Unidentified Codec ($codec)"
		exit 1
	fi
	if [ "$vcheck" != 'true' ] && [ -z "$KEEP" ]
	then
		rm "${OPATH}/show/$title/${FILENAME}.ts"
	fi

	$wget_c -O "${OPATH}/content/${SHOW_ID}_${d_date}.livestatus" https://now.naver.com/api/nnow/v1/stream/${SHOW_ID}/livestatus
	total_user=$(cat "${OPATH}/content/${SHOW_ID}_${d_date}.livestatus" | grep -oP 'cumulativeUserCount":\K[^}]+')
	msg "\n오늘 조회수: $total_user"

	info_msg "\nJob Finished, Code: $SREASON\n"
	exit 0 ### SCRIPT FINISH
}

function renamer()
{
	str=$1
	str=${str//'"'/''}
	str=${str//'\r\n'/' '}
	str=${str//'\'/''}
	export $2="$str"
}

function exrefresh()
{
	unset url title startdate starttime
	showhost=$(cat "${OPATH}/content/${SHOW_ID}_${d_date}.content" | grep -oP '호스트: \K[^\\r]+')
	title=$(cat "${OPATH}/content/${SHOW_ID}_${d_date}.content" | grep -oP 'home":{"title":{"text":"\K[^"]+')
	vcheck=$(cat "${OPATH}/content/${SHOW_ID}_${d_date}.content" | grep -oP 'video":\K[^,]+')
	if [ "$vcheck" = 'true' ]
	then
		url=$(cat "${OPATH}/content/${SHOW_ID}_${d_date}.livestatus" | grep -oP 'videoStreamUrl":"\K[^"]+')
	else
		url=$(cat "${OPATH}/content/${SHOW_ID}_${d_date}.livestatus" | grep -oP 'liveStreamUrl":"\K[^"]+')
	fi
	startdate=$(cat "${OPATH}/content/${SHOW_ID}_${d_date}.livestatus" | grep -oP 'startDatetime":"20\K[^T]+')
	starttime=$(cat "${OPATH}/content/${SHOW_ID}_${d_date}.livestatus" | grep -oP 'startDatetime":"\K[^"]+' | grep -oP 'T\K[^.+]+')
	subject=$(jq '.contentList[].title.text' "${OPATH}/content/${SHOW_ID}_${d_date}.content")
	des=$(jq -r '.contentList[].description.text' "${OPATH}/content/${SHOW_ID}_${d_date}.content")
	ep=$(cat "${OPATH}/content/${SHOW_ID}_${d_date}.content" | grep -oP '"count":"\K[^회"]+')
	onair=$(cat "${OPATH}/content/${SHOW_ID}_${d_date}.livestatus" | grep -oP ${SHOW_ID}'","status":"\K[^"]+') # READY | END | ONAIR

	renamer "$subject" subject

	if [ -d "${OPATH}/show/$title" ]
	then
		echo -e "Host: $showhost\nEP: $ep\n\n$subject\n\n$des" > "${OPATH}/show/$title/${d_date}_${showhost}_Info.txt"
	fi

	startdate=${startdate//'-'/}
	starttime=${starttime//':'/}

	if [ -z "$url" ] || [ -z "$title" ] || [ -z "$startdate" ] || [ -z "$starttime" ]
	then
		curl_c="curl"
		wget_c="wget"
		if [ "$MAXRETRY" = "0" ]
		then
			err_msg "\nexrefresh(): 정보 업데이트 실패, 스크립트 종료\n"
			content_backup
			exit 1
		fi
		if [ "$EXRETRY" != "0" ]
		then
			echo -e "\n재시도 횟수: $EXRETRY / 최대 재시도 횟수: $MAXRETRY"
		fi
		if [ -z "$EXRETRY" ] || [ "$EXRETRY" -lt "$MAXRETRY" ]
		then
			err_msg "정보 업데이트 실패, 재시도 합니다"
			((EXRETRY++))
		elif [ "$EXRETRY" -ge "$MAXRETRY" ]
		then
			err_msg "\nexrefresh(): 정보 업데이트 실패\n최대 재시도 횟수($MAXRETRY회) 도달, 스크립트 종료\n"
			content_backup
			exit 1
		else
			err_msg "\nERROR: exrefresh(): EXRETRY\n"
			content_backup
			exit 1
		fi
		msg "\nSTARTDATE: $startdate\nSTARTTIME: $starttime\nTITLE:$title\nURL:$url\n"
		msg "Retrying...\n"
		contentget
		exrefresh
	fi
	alert_msg "Show Info variables refreshed"
	EXRETRY=0
	curl_c="curl --no-progress-meter"
	wget_c="wget -q"
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
	if [ "$vcheck" = 'true' ]
	then
		FILENAME="${d_date}.NAVER NOW.$title.E$ep.${subject}_VID_$hour$min$sec"
	else
		FILENAME="${d_date}.NAVER NOW.$title.E$ep.${subject}_$hour$min$sec"
	fi
	FILENAME=${FILENAME//'/'/' '}
	FILENAME=${FILENAME//'%'/'%%'}
	alert_msg "Time variables refreshed\n"
}

function counter()
{
	TIMER=$1
	if [ "$TIMER" = 0 ]
	then
		echo
	elif [ "$TIMER" -gt 0 ]
	then
		msg "\n총 $TIMER초 동안 대기합니다"
		while [ "$TIMER" -gt 0 ]
		do
			echo "$TIMER초 남음"
			sleep 1
			if [ -t 1 ]
			then
				tput cuu1;tput el
			fi
			((TIMER--))
		done
		echo -e '\n'
	fi
	unset TIMER
}

function onairwait()
{
	W_TIMER=0
	while :
	do
		echo -e '방송이 시작되지 않았습니다\n'
		timeupdate	
		echo -e 'Time difference: '"$timecheck"' min'

		if [ "$timecheck" -le -15 ]
		then
			line=$(expr $(grep -n '"contentId": "'${SHOW_ID}'"' "${OPATH}/content/${d_date}_LiveList.txt" | cut -d : -f 1) + 3)
			b_day=$(sed -n ${line}p "${OPATH}/content/${d_date}_LiveList.txt" | cut -d '"' -f 4)
			err_msg "\nERROR: 시작시간과 15분 이상 차이 발생\n금일 방송 유무를 확인해주세요"
			err_msg "\n쇼 이름: $title\n방송 시간: $b_day\n"
			exit 1
		fi

		counter "$W_TIMER"
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
			W_TIMER=3600
		# 시작 시간이 65분 미만 차이
		elif [ "$timecheck" -lt 65 ]
		then
			# 시작 시간이 12분 초과 차이
			if [ "$timecheck" -gt 12 ]
			then
				W_TIMER=600
			# 시작 시간이 12분 이하 차이
			elif [ "$timecheck" -le 12 ]
			then
				# 시작 시간이 3분 초과 차이
				if [ "$timecheck" -gt 3 ]
				then
					W_TIMER=60
				# 시작 시간이 3분 이하 차이
				elif [ "$timecheck" -le 3 ]
				then
					W_TIMER=1
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
			counter 3
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
	# Live Status
	$wget_c -O "${OPATH}/content/${d_date}_LiveList.html" https://now.naver.com/api/nnow/v1/stream/livelist
	jq '.liveList[]' "${OPATH}/content/${d_date}_LiveList.html" > "${OPATH}/content/${d_date}_LiveList.txt"
	rm "${OPATH}/content/${d_date}_LiveList.html"

	contentget
	exrefresh
	timeupdate

	if [ ! -d "${OPATH}/show/$title" ]
	then
		mkdir -p "${OPATH}/show/$title"
	fi

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
		counter $CUSTIMER
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