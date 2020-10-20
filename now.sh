#!/bin/bash

#------------------------------------------------------------------
#
# Now Downloader
#
# Created on 2020 May 12
#
# Author: TheNoFace (thenoface303@gmail.com)
#
# TODO:
# 200531) 방송 시각과 현재 시각 차이가 20분 이상이면 (시각차이-20)분 sleep
# 200812) 방송 요일 구해서 금일 방송이 아니라면 자동 custimer
# 200829) onairwait 대기 중 24시 넘어가면 Time Difference +24시간 재설정
# 201015) 시간 기반(PTIMETH) 스트리밍 중단 확인 방식 -> 파일 크기 변화 감지 방식으로 변경
# 201018) onairwait(): TIMECHECK의 60% 이상 분단위 sleep
# 201018) Verbose 모드에서만 표시할 메세지 정리
# 201018) Log 내재화
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

NDV="1.3.1"
BANNER="Now Downloader v$NDV"
SCRIPT_NAME=$(basename $0)

P_LIST=(bc jq youtube-dl ffmpeg)
P_LIST_E=0

SHOW_ID=""
FORCE=""
KEEP=""
OPATH_I=""
ITG_CHECK=""
N_RETRY=""
MAXRETRYSET=10
CHKINTSET=60
CUSTIMER=""
SREASON=""
VERB=""

CTRETRY="0"
RETRY="0"
EXRETRY="0"
S_RETRY="0"

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

function timelog()
{
	TIMELOG=$(echo "[$(date +'%x %T')]")
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
				ITG_CHECK=1 ; shift ;;
			-r|--maxretry)
				MAXRETRY="$2" ; shift ; shift ;;
			-dr|--dretry)
				N_RETRY=1 ; shift ;;
			-t|--chkint)
				CHKINT="$2" ; shift ; shift ;;
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
  -vb | --verbose             Display wget download information
  -f  | --force               Start download immediately without any time checks
  -k  | --keep                Do not delete original audio stream(.ts) file after download finishes
  -o  | --opath <dir>         Overrides output path to check if it's been set before
  -dc | --dcont               Do not check integrity of content/livestatus files in content folder
  -r  | --maxretry [number]   Maximum retries if download fails
                              Default is set to $MAXRETRYSET times
  -dr | --dretry              Disable retries (same as -r 0)
  -t  | --chkint [seconds]    Check stream status if it has ended abnormally by checking file size
                              Default is set to $CHKINTSET seconds
  -c  | --custimer [seconds]  Custom sleep timer before starting script"
	alert_msg "                              WARNING: Mandatory if today is not the broadcasting day"

	echo "Notes:
  - Short options should not be grouped. You must pass each parameter on its own.
  - Disabling flags priors than setting flags

Example:
* $SCRIPT_NAME -i 495 -o /home/$USER/now -r 100 -t 30 -c 86400
  - Override output directory to /home/$USER/now
  - Wait 86400 seconds (24hr) before starting this script
  - Download #495 show
  - Retries 100 times if download fails
  - Check stream status for every 30 seconds
* $SCRIPT_NAME -i 495 -f -dr -k
  - Do not retry download even if download fails
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
			exit 3
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
		exit 4
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
		wget_c="wget"
		youtube_c="youtube-dl"
		ffmpeg_c="ffmpeg"
	else
		wget_c="wget -q"
		youtube_c="youtube-dl -q"
		ffmpeg_c="ffmpeg -loglevel quiet"
	fi

	if [ -n "$FORCE" ]
	then
		alert_msg "Force Download Enabled"
	fi

	if [ -n "$KEEP" ]
	then
		alert_msg "Keep original audio stream file after download has finished"
	fi

	if [ -z "$CUSTIMER" ]
	then
		alert_msg "Custom timer before start is not set"
	fi

	if [ -n "$ITG_CHECK" ]
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
			echo -e "If you want to change output path, delete ${YLW}$PWD/.opath${NC} file or use -o option"
			dir_check
		else
			err_msg "\nERROR: script_init OPATH\n"
			exit 5
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

	if [ -z $N_RETRY ]
	then
		if [ -z $MAXRETRY ]
		then
			alert_msg "Maximum retry set to default ($MAXRETRYSET times)"
			MAXRETRY=$MAXRETRYSET
			echo "maxretry $MAXRETRY / maxretryset $MAXRETRYSET"
		else
			alert_msg "Maximum retry set to $MAXRETRY times"
		fi
	elif [ -n $N_RETRY ]
	then
		MAXRETRY=0
		alert_msg "Retry Disabled"
		echo "maxretry $MAXRETRY / maxretryset $MAXRETRYSET"
	fi

	if [ -z $CHKINT ]
	then
		alert_msg "Stream status check timer set to default ($CHKINTSET seconds)"
		CHKINT=$CHKINTSET
		echo "chkint $CHKINT / chkintset $CHKINTSET"
	else
		alert_msg "Stream status check timer set to $CHKINT seconds"
	fi

	if [ -n "$CUSTIMER" ]
	then
		alert_msg "Custom sleep timer set to ${CUSTIMER}s"
	fi

	if [ -z "$N_RETRY" ] || [ -n "$CUSTIMER" ]
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
		if [ "$ONAIR" = "ONAIR" ]
		then
			msg "방송 상태: $ONAIR\n접속자 수: $cur_user / 오늘 총 조회수: $total_user\n"
		else
			msg "방송 상태: $ONAIR\n총 조회수: $total_user\n"
		fi
		exit 0
	fi
}

# content: general information of show
# livestatus: audio/video stream information of show
function contentget()
{
	$wget_c -O "${OPATH}/content/${SHOW_ID}_${d_date}.livestatus" https://now.naver.com/api/nnow/v1/stream/${SHOW_ID}/livestatus
	$wget_c -O "${OPATH}/content/${SHOW_ID}_${d_date}.content" https://now.naver.com/api/nnow/v1/stream/${SHOW_ID}/content
	if [ -z $ITG_CHECK ]
	then
		ctlength=$(wc -c "${OPATH}/content/${SHOW_ID}_${d_date}.content" | awk '{print $1}')
		lslength=$(wc -c "${OPATH}/content/${SHOW_ID}_${d_date}.livestatus" | awk '{print $1}')
		msg "content: $ctlength Bytes / livestatus: $lslength Bytes"
		if [ "$ctlength" -lt 2500 ] && [ "$lslength" -lt 1000 ]
		then
			if [ "$MAXRETRY" = "0" ]
			then
				err_msg "content/livestatus 파일이 올바르지 않음, 스크립트 종료\n"
				content_backup
				exit 1
			fi
			alert_msg "content/livestatus 파일이 올바르지 않음, 다시 시도합니다"
			while :
			do
				((CTRETRY++))
				msg "\n재시도 횟수: $CTRETRY / 최대 재시도 횟수: $MAXRETRY\n"
				$wget_c -O "${OPATH}/content/${SHOW_ID}_${d_date}.livestatus" https://now.naver.com/api/nnow/v1/stream/${SHOW_ID}/livestatus
				$wget_c -O "${OPATH}/content/${SHOW_ID}_${d_date}.content" https://now.naver.com/api/nnow/v1/stream/${SHOW_ID}/content
				ctlength=$(wc -c "${OPATH}/content/${SHOW_ID}_${d_date}.content" | awk '{print $1}')
				lslength=$(wc -c "${OPATH}/content/${SHOW_ID}_${d_date}.livestatus" | awk '{print $1}')
				msg "content: $ctlength Bytes / livestatus: $lslength Bytes"
				if [ "$ctlength" -lt 2500 ] && [ "$lslength" -lt 1000 ]
				then
					if [ "$CTRETRY" -lt "$MAXRETRY" ]
					then
						alert_msg "content/livestatus 파일이 올바르지 않음, 다시 시도합니다"
					elif [ "$CTRETRY" -ge "$MAXRETRY" ]
					then
						err_msg "최대 재시도 횟수($MAXRETRY회) 도달, 스크립트 종료\n"
						content_backup
						exit 1
					else
						err_msg "\nERROR: contentget(): CTRETRY,MAXRETRY\n"
						content_backup
						exit 1
					fi
				elif [ "$ctlength" -ge 2500 ] && [ "$lslength" -ge 1000 ]
				then
					info_msg "정상 content/livestatus 파일\n"
					break
				else
					err_msg "\nERROR: contentget(): ctlength 1\n"
					content_backup
					exit 1
				fi
			done
		elif [ "$ctlength" -ge 2500 ] && [ "$lslength" -ge 1000 ]
		then
			info_msg "정상 content/livestatus 파일\n"
		else
			err_msg "\nERROR: contentget(): ctlength 2\n"
			content_backup
			exit 1
		fi
		CTRETRY=0
	else
		alert_msg "Passed integrity check!"
	fi
}

function content_backup()
{
	mv "${OPATH}/content/${SHOW_ID}_${d_date}.content" "${OPATH}/content/_ERR_${SHOW_ID}_${d_date}_$CTIME.content"
	mv "${OPATH}/content/${SHOW_ID}_${d_date}.livestatus" "${OPATH}/content/_ERR_${SHOW_ID}_${d_date}_$CTIME.livestatus"
	if [ -e "${OPATH}/content/${SHOW_ID}_${d_date}_LiveList.txt" ]
	then
		mv "${OPATH}/content/${SHOW_ID}_${d_date}_LiveList.txt" "${OPATH}/content/_ERR_${SHOW_ID}_${d_date}_${CTIME}_LiveList.txt"
	fi
}

function getstream()
{
	if [ $RETRY = 0 ]
	then
		INFO=$(jq -r '.contentList[].description.text' "${OPATH}/content/${SHOW_ID}_${d_date}.content")
		echo -e "Host: $showhost\nEP: $ep\n\n$subject\n\n$INFO" > "${OPATH}/show/$title/${d_date}_${showhost}_Info.txt"
	fi

	msg "방송시간: $starttime / 현재: $CTIME"
	if [ "$vcheck" = 'true' ]
	then
		alert_msg "\n보이는 쇼 입니다"
	fi
	msg "\n$title E$ep $subject\n${FILENAME}.ts\n$url\n"
	#-ERROR-CHECK------------------------------------------------------
	$youtube_c --hls-use-mpegts --no-part "$url" --output "${OPATH}/show/$title/${FILENAME}.ts" & YPID=$!

	msg "[$(date +'%x %T')] Download Started, checking stream status every ${YLW}$CHKINT${NC} seconds"
	sleep 10 # wait for ffmpeg to start
	FPID=$(ps --ppid $YPID | awk 'FNR == 2 {print $1}')
	PIDS=($YPID $FPID)

	while :
	do
		INITSIZE=$(wc -c "${OPATH}/show/$title/${FILENAME}.ts" | cut -d ' ' -f 1)
		sleep $CHKINT
		POSTSIZE=$(wc -c "${OPATH}/show/$title/${FILENAME}.ts" | cut -d ' ' -f 1)
		msg "[$(date +'%x %T')] INIT: ${YLW}$INITSIZE${NC} Bytes / POST: ${GRN}$POSTSIZE${NC} Bytes"

		$wget_c -O "${OPATH}/content/${SHOW_ID}_${d_date}.livestatus" https://now.naver.com/api/nnow/v1/stream/${SHOW_ID}/livestatus
		ONAIR=$(cat "${OPATH}/content/${SHOW_ID}_${d_date}.livestatus" | grep -oP ${SHOW_ID}'","status":"\K[^"]+')
		msg "[$(date +'%x %T')] Show Status: ${GRN}$ONAIR${NC}"

		if [ $ONAIR = 'ONAIR' ]
		then
			if [ -t 1 ]
			then
				tput cuu 2
			fi
			if [ $INITSIZE == $POSTSIZE ]
			then
				if [ -t 1 ]
				then
					tput cud 2
				fi
				err_msg "$CHKINT초 동안 다운로드 중단됨, 다시 시도합니다\n"
				kill ${PIDS[@]}
				contentget
				exrefresh
				timeupdate
				getstream
			fi
		elif [ $ONAIR != 'ONAIR' ]
		then
			msg "[$(date +'%x %T')] 스트리밍 종료됨"
			break
		fi
	done
	convert
}

function convert()
{
	codec=$(ffprobe -v error -show_streams -select_streams a "${OPATH}/show/$title/${FILENAME}.ts" | grep -oP 'codec_name=\K[^+]*')
	if [ "$vcheck" = 'true' ]
	then
		alert_msg "\nFound video stream, passed audio converting... ($codec)"
		msg "Download Complete: ${OPATH}/show/$title/${FILENAME}.ts"
	elif [ "$vcheck" != 'true' ]
	then
		if [ "$codec" = 'mp3' ]
		then
			msg "\nCodec: MP3, Saving into mp3 file"
			$ffmpeg_c -i "${OPATH}/show/$title/${FILENAME}.ts" -vn -c:a copy "${OPATH}/show/$title/${FILENAME}.mp3"
			msg "Convert Complete: ${OPATH}/show/$title/${FILENAME}.mp3"
		elif [ "$codec" = 'aac' ]
		then
			msg "\nCodec: AAC, Saving into m4a file"
			$ffmpeg_c -i "${OPATH}/show/$title/${FILENAME}.ts" -vn -c:a copy "${OPATH}/show/$title/${FILENAME}.m4a"
			msg "Convert Complete: ${OPATH}/show/$title/${FILENAME}.m4a"
		else
			err_msg "\nERROR: Unidentified Codec ($codec)"
			content_backup
			exit 1
		fi
		if [ -z "$KEEP" ]
		then
			rm "${OPATH}/show/$title/${FILENAME}.ts"
		fi
	fi

	$wget_c -O "${OPATH}/content/${SHOW_ID}_${d_date}.livestatus" https://now.naver.com/api/nnow/v1/stream/${SHOW_ID}/livestatus
	total_user=$(cat "${OPATH}/content/${SHOW_ID}_${d_date}.livestatus" | grep -oP 'cumulativeUserCount":\K[^}]+')
	msg "\n오늘 총 조회수: $total_user"

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
	ORI_DATE=$(cat "${OPATH}/content/${SHOW_ID}_${d_date}.livestatus" | grep -oP 'startDatetime":"\K[^"]+' | xargs -i date -d {} +%s) # Seconds since 1970-01-01 00:00:00 UTC
	startdate=$(date -d @$ORI_DATE +'%y%m%d')
	starttime=$(date -d @$ORI_DATE +'%H%M%S')
	subject=$(jq '.contentList[].title.text' "${OPATH}/content/${SHOW_ID}_${d_date}.content")
	ep=$(cat "${OPATH}/content/${SHOW_ID}_${d_date}.content" | grep -oP '"count":"\K[^회"]+')
	ONAIR=$(cat "${OPATH}/content/${SHOW_ID}_${d_date}.livestatus" | grep -oP ${SHOW_ID}'","status":"\K[^"]+') # READY | END | ONAIR

	renamer "$subject" subject

	if [ -z "$G_USR" ]
	then
		if [ -z "$url" ] || [ -z "$title" ] || [ -z "$startdate" ] || [ -z "$starttime" ]
		then
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
		EXRETRY=0
	fi
	alert_msg "Show Info variables refreshed"
}

function timeupdate()
{
	d_date=$(date +'%y%m%d')
	CTIME=$(date +'%H%M%S')
	TIMECHECK=$(echo "($(date -d @$ORI_DATE +%H)*60+$(date -d @$ORI_DATE +%M))-($(date +%H)*60+$(date +%M))" | bc -l)
	if [ "$vcheck" = 'true' ]
	then
		FILENAME="${d_date}.NAVER NOW.$title.E$ep.${subject}_VID_$CTIME"
	else
		FILENAME="${d_date}.NAVER NOW.$title.E$ep.${subject}_$CTIME"
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
		echo -e 'Time difference: '"$TIMECHECK"' min'

		if [ "$TIMECHECK" -le -15 ]
		then
			line=$(expr $(grep -n '"contentId": "'${SHOW_ID}'"' "${OPATH}/content/${SHOW_ID}_${d_date}_LiveList.txt" | cut -d : -f 1) + 3)
			b_day=$(sed -n ${line}p "${OPATH}/content/${SHOW_ID}_${d_date}_LiveList.txt" | cut -d '"' -f 4)
			err_msg "\nERROR: 시작시간과 15분 이상 차이 발생\n금일 방송 유무를 확인해주세요"
			err_msg "\n쇼 이름: $title\n방송 시간: $b_day (KST)\n"
			content_backup
			exit 1
		fi

		counter "$W_TIMER"
		echo -e 'content/livestatus 다시 불러오는 중...\n'
		contentget
		exrefresh
		timeupdate
		echo -e '방송일  : '"$startdate"' / 오늘: '"${d_date}"
		msg "방송시간: $starttime / 현재: $CTIME"
		if [ "$vcheck" = 'true' ]
		then
			alert_msg "\n보이는 쇼 입니다"
		fi
		echo -e "\n$title E$ep $subject\n$url\n"
		if [ "$TIMECHECK" -ge 65 ]
		then
			W_TIMER=3600
		# 시작 시간이 65분 미만 차이
		elif [ "$TIMECHECK" -lt 65 ]
		then
			# 시작 시간이 12분 초과 차이
			if [ "$TIMECHECK" -gt 12 ]
			then
				W_TIMER=600
			# 시작 시간이 12분 이하 차이
			elif [ "$TIMECHECK" -le 12 ]
			then
				# 시작 시간이 3분 초과 차이
				if [ "$TIMECHECK" -gt 3 ]
				then
					W_TIMER=60
				# 시작 시간이 3분 이하 차이
				elif [ "$TIMECHECK" -le 3 ]
				then
					W_TIMER=1
				else
					err_msg "\nERROR: onairwait(): 1\n"
					content_backup
					exit 1
				fi
			else
				err_msg "\nERROR: onairwait(): 2\n"
				content_backup
				exit 1
			fi
		else
			err_msg "\nERROR: onairwait(): 3\n"
			content_backup
			exit 1
		fi
		# 방송 상태 확인
		if [ "$ONAIR" != "ONAIR" ]
		then
			msg "Live Status: ${YLW}$ONAIR${NC}\n"
		elif [ "$ONAIR" = "ONAIR" ]
		then
			msg "Live Status: ${GRN}$ONAIR${NC}\n"
			info_msg "content/livestatus 불러오기 완료\n"
			break
		elif [ -z "$ONAIR" ]
		then
			alert_msg "\nWARNING: onairwait(): Couldn't get show status"
			alert_msg "Retrying...\n"
		else
			err_msg "ERROR: onairwait(): 4\n"
			content_backup
			exit 1
		fi
	done
}

function main()
{
	# Live Status
	$wget_c -O "${OPATH}/content/${SHOW_ID}_${d_date}_LiveList.html" https://now.naver.com/api/nnow/v1/stream/livelist
	jq '.liveList[]' "${OPATH}/content/${SHOW_ID}_${d_date}_LiveList.html" > "${OPATH}/content/${SHOW_ID}_${d_date}_LiveList.txt"
	rm "${OPATH}/content/${SHOW_ID}_${d_date}_LiveList.html"

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
	msg "방송시간: $starttime / 현재: $CTIME"
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
	else
		err_msg "\nERROR: CUSTIMER\n"
		exit 6
	fi

	if [ -n "$FORCE" ]
	then
		SREASON="FORCE"
		getstream
	fi

	if [ "$ONAIR" != "ONAIR" ]
	then
		msg "Live Status: ${YLW}$ONAIR${NC}\n"
		onairwait
		# 시작 시간이 됐을 경우
		if [ "$CTIME" -ge "$starttime" ]
		then
			info_msg "쇼가 시작됨\n"
			SREASON=1
			getstream
		# 시작 시간이 안됐을 경우
		elif [ "$CTIME" -lt "$starttime" ]
		then
			alert_msg "쇼가 아직 시작되지 않음\n"
			while :
			do
				msg "방송시간: $starttime / 현재: $CTIME"
				msg "\n대기 중...($CTIME)"
				sleep 1
				contentget
				exrefresh
				timeupdate
				# 시작 시간 확인
				if [ "$CTIME" -ge "$starttime" ]
				then
					msg "방송시간: $starttime / 현재: $CTIME"
					info_msg "쇼가 시작됨\n"
					break
				fi
			done
			SREASON=2
			getstream
		else
			err_msg "\nERROR: 1\n"
			content_backup
			exit 1
		fi
	elif [ "$ONAIR" = "ONAIR" ]
	then
		msg "Live Status: ${GRN}$ONAIR${NC}\n"
		info_msg "쇼가 시작됨\n"
		SREASON=3
		getstream
	else
		err_msg "ERROR: 2\n"
		content_backup
		exit 1
	fi
}

### SCRIPT START

get_parms "$@"
script_init
main

err_msg "ERROR: EOF\n"
exit 10
