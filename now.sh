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
# 201018) onairwait(): TIMECHECK의 60% 이상 분단위 sleep
# 201018) Verbose 모드에서만 표시할 메세지 정리
# 201018) Log 내재화
# 201109) getstream()에서 URL 확인 시 MAXRETRY 제한
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

NDV="1.5.1"
BANNER="Now Downloader v$NDV"
SCRIPT_NAME=$(basename $0)
oriIFS=$IFS

P_LIST=(bc jq curl wget ffmpeg)
dirList=(content log show chat)

NOW_LINK='https://apis.naver.com/now_web/nowapi-xhmac/nnow/v2/stream'

SHOW_ID=""
FORCE=""
KEEP=""
OPATH_I=""
ITG_CHECK=""
N_RETRY=""
MAXRETRYSET=10
CHKINTSET=30
chatCheckInterval=1
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
	if [ "$1" = '-t' ] && is_not_empty "$2"
	then
		echo -e "${RED}[$(date +'%x %T')] $2${NC}"
	elif is_not_empty "$1"
	then
		echo -e "${RED}$1${NC}"
	fi
}

function alert_msg()
{
	if [ "$1" = '-t' ] && is_not_empty "$2"
	then
		echo -e "${YLW}[$(date +'%x %T')] $2${NC}"
	elif is_not_empty "$1"
	then
		echo -e "${YLW}$1${NC}"
	fi
}

function info_msg()
{
	if [ "$1" = '-t' ] && is_not_empty "$2"
	then
		echo -e "${GRN}[$(date +'%x %T')] $2${NC}"
	elif is_not_empty "$1"
	then
		echo -e "${GRN}$1${NC}"
	fi
}

function msg()
{
	if [ "$1" = '-t' ] && is_not_empty "$2"
	then
		echo -e "[$(date +'%x %T')] $2"
	elif is_not_empty "$1"
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
			--version)
				print_banner ; exit 0 ;;
			--help)
				print_help ; exit 0 ;;
			-l|--list)
				availableArg="live"
				if [ "$2" = 'live' ]
				then
					isListLive=1
				elif [ -n "$2" ]
				then
					isError=1
					errArg="$2"
					isListLive=1
				else
					isListLive=0
				fi
				get_list ; exit 0 ;;
			-i|--id)
				SHOW_ID="$2" ; shift ; shift ;;
			-f|--force)
				FORCE=1 ; shift ;;
			-k|--keep)
				KEEP=1 ; shift ;;
			-o|--output)
				OPATH_I="$2" ; shift ; shift ;;
			-nc|--no-check)
				ITG_CHECK=1 ; shift ;;
			-r|--retry)
				MAXRETRY="$2" ; shift ; shift ;;
			-nr|--no-retry)
				N_RETRY=1 ; shift ;;
			-t|--time-check)
				CHKINT="$2" ; shift ; shift ;;
			--custimer)
				CUSTIMER="$2" ; shift ; shift ;;
			-v|--verbose)
				VERB=1 ; shift ;;
			-u|--user)
				G_USR=1 ; shift ;;
			--info)
				GetInfo=1 ; shift ;;
			-c|--chat)
				showChat=1 ; managerOnly=1 ; shift ;;
			--chat-all)
				showChat=1 ; managerOnly=0 ; shift ;;
			*)
				check_invalid_parms "$1" ; break ;;
		esac
	done
}

function check_invalid_parms()
{
	if is_not_empty "$1"
	then
		print_help
		err_msg "Invalid Option: $1\n"
		exit 2
	elif [ -z ${SHOW_ID} ]
	then
		print_help
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
  -c  | --chat                Print live or recent host/manager's chats and save into file
        --chat-all            Print live or recent chats and save into file"
	alert_msg "                              NOTE: File is saved after the show has finished (ONAIR -> END)"
	echo "        --custimer [second]   Custom sleep timer before starting script"
	alert_msg "                              NOTE: Mandatory if today is not the broadcasting day"
	echo "  -f  | --force               Start download immediately without any time checks
        --info                Display detailed info of the show
  -k  | --keep                Do not delete original audio stream(.ts) file after download finishes
  -l  | --list (live)         List every shows' ID and titles then exits
                              live: List shows' ID and titles that are currently on air
  -nc | --no-check            Do not check integrity of content/livestatus files in content folder
  -nr | --no-retry            Disable retries (same as -r 0)
  -o  | --output <dir>        Overrides output path to check if it's been set before
  -r  | --retry [number]      Maximum retries if download fails
                              Default is set to $MAXRETRYSET times
  -t  | --time-check [second] Check stream status if it has ended abnormally by checking file size
                              Default is set to $CHKINTSET seconds
  -u  | --user                Display current/total users of the show
  -v  | --verbose             Print wget/ffmpeg messages

        --help                Show this help screen
        --version             Show program name and version

Notes:
  - Short options should not be grouped. You must pass each parameter on its own.
  - Disabling flags priors than setting flags

Example:
* $SCRIPT_NAME -i 495 -o /home/$USER/now -r 100 -t 60 -c 86400
  - Override output directory to /home/$USER/now
  - Wait 86400 seconds (24hr) before starting this script
  - Download #495 show
  - Retries 100 times if download fails
  - Check stream status for every 60 seconds
* $SCRIPT_NAME -i 495 -f -nr -nc -k
  - Do not retry download even if download fails
  - Do not check integrity of content/livestatus files in content folder
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

function package_check()
{
	for l in ${P_LIST[@]}
	do
		P=$(command -v $l)
		if [ -z $P ]
		then
			NFOUND=(${NFOUND[@]} $l)
		fi
	done

	if [ ${#NFOUND[@]} != 0 ]
	then
		print_banner
		array=${NFOUND[@]}
		err_msg "Couldn't find follow package(s): $array"
		err_msg "Please install required package(s)\n"
		exit 4
	else
		if [ -t 1 ]
		then
			print_banner
		else
			msg "\n---$BANNER-----------ShowID: ${SHOW_ID}-----------$(date +'%F %a %T')---\n"
		fi
	fi
}

function script_init()
{
	d_date=$(date +'%y%m%d')
	package_check

	[ -n "$GetInfo" ] && get_info

	if [ -z ${OPATH_I} ]
	then
		if [ ! -e .opath ]
		then
			echo -e "Seems like it's your first time to run this scipt"
			echo -n "Please enter directory to save (e.g: /home/$USER/now): "
			read OPATH
			OPATH=${OPATH/"~"/"/home/$USER"}
			dir_check
		elif [ -e .opath ]
		then
			OPATH=$(cat .opath)
			echo -e "Output Path: ${YLW}${OPATH}${NC}"
			echo -e "If you want to change output path, delete ${YLW}$PWD/.opath${NC} file or use -o option"
			dir_check
		else
			err_msg "ERROR: script_init OPATH\n"
			exit 5
		fi
	elif [ -n ${OPATH_I} ]
	then
		OPATH=${OPATH_I/"~"/"/home/$USER"}
		echo -e "Output Path: ${YLW}${OPATH} (Overrided)${NC}"
		dir_check
	fi

	for i in ${dirList[@]}
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

	if [ "$showChat" = 1 ]
	then
		livestatusURL="${NOW_LINK}/$SHOW_ID/livestatus"
		chatId=$(curl -s $livestatusURL | jq -r '.status.clientConfig.poll.comment.objectId')
		chatURL="https://apis.naver.com/now_web/now-chat-api/list?object_id=$chatId"
		show_chat
	fi

	if [ -n "$VERB" ] # https://unix.stackexchange.com/a/444949
	then
		alert_msg "Verbose Mode"
		wget_c=(wget)
		ffmpeg_c=(ffmpeg)
	else
		wget_c=(wget -q)
		ffmpeg_c=(ffmpeg -loglevel quiet)
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

	if [ -z $N_RETRY ]
	then
		if [ -z $MAXRETRY ]
		then
			alert_msg "Maximum retry set to default ($MAXRETRYSET times)"
			MAXRETRY=$MAXRETRYSET
		else
			alert_msg "Maximum retry set to $MAXRETRY times"
		fi
	elif [ -n $N_RETRY ]
	then
		MAXRETRY=0
		alert_msg "Retry Disabled"
	fi

	if [ -z $CHKINT ]
	then
		alert_msg "Stream status check timer set to default ($CHKINTSET seconds)"
		CHKINT=$CHKINTSET
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
		cur_user=$(echo "${livestatus}" | jq -r .status.indicator.concurrentUserCount)
		total_user=$(echo "${livestatus}" | jq -r .status.indicator.cumulativeUserCount)

		msg "\n$startdate $title by ${showhost}\n$subject"
		if [ "$STATUS" = "ONAIR" ]
		then
			msg "방송 상태: ${RED}$STATUS${NC}\n접속자 수: $cur_user / 오늘 총 조회수: $total_user\n"
		else
			msg "방송 상태: $STATUS\n총 조회수: $total_user\n"
		fi
		exit 0
	fi
}

function get_info()
{
	content=$(curl -s "${NOW_LINK}/$SHOW_ID/content")
	echo "$content" | jq -e '.contentList[].home.title.text' > /dev/null & JQPID=$!
	wait $JQPID; ExitCode=$?

	if [ $ExitCode != 0 ]
	then
		err_msg "Invalid Show ID, Use --list option to list available shows!\n"
		exit 6
	fi

	guest=$(echo "$content" | jq -r '.contentList[] | (.description.clova.guest | join(","))')
	if [ -z "$guest" ]
	then
		info=$(echo "$content" | jq -r '.contentList[] | .home.title.text + " by " + (.description.clova.host | join(", ")) + "\n\n" + .title.text + "\n\n" + .description.text')
	else
		info=$(echo "$content" | jq -r '.contentList[] | .home.title.text + " by " + (.description.clova.host | join(", ")) + "\nGuest: " + (.description.clova.guest|join(",")) + "\n\n" + .title.text + "\n\n" + .description.text')
	fi

	msg "${info}\n"
	unset GetInfo
	proceed_download ${SHOW_ID}
}

function get_chat()
{
	get_status
	IFS=$'\n'
	# chatList=($(curl -s $chatURL | jq -r '[.result.recentManagerCommentList[] | .userName + ": " + .contents] | reverse[]'))
	# timelist=($(curl -s $chatURL | jq -r '[.result.recentManagerCommentList[] | .regTime] | reverse[]'))
	if [ "$managerOnly" = 1 ]
	then
		if [ -z $notFirst ] && [ "$STATUS" = "END" ]
		then
			chatList=($(curl -s $chatURL | jq -r '[.result.recentManagerCommentList[] | "[" + .regTime + "] " + .userName + ": " + .contents] | reverse[]'))
		else
			chatList=($(curl -s $chatURL | jq -r '[.result.commentList[] | select(.manager == true) | "[" + .regTime + "] " + .userName + ": " + .contents] | reverse[]'))
		fi
	elif [ "$managerOnly" = 0 ]
	then
		chatList=($(curl -s $chatURL | jq -r '[.result.commentList[] | "[" + .regTime + "] " + .userName + ": " + .contents] | reverse[]'))
	fi

	cumulatedList=(${cumulatedList[@]} ${chatList[@]})
	if [ ${#cumulatedList[@]} -lt 20 ]
	then
		chatArrayStart=0
	else
		chatArrayStart=$[${#cumulatedList[@]} - 20]
	fi
	if [ -z $notFirst ]
	then
		sortedList=($(printf "%s\n" "${cumulatedList[@]}" | sort -u))
	fi
}

function show_chat()
{
	while :
	do
		get_chat

		if [ "$notFirst" = 1 ]
		then
			unset sortedList listToPrint
			for (( i = $chatArrayStart; i < ${#cumulatedList[@]}; i++ ))
			do
				sortedList=(${sortedList[@]} ${cumulatedList[$i]})
			done
			listToPrint=($(printf "%s\n" "${sortedList[@]}" | sort -u))
			printf "%s\n" "${listToPrint[@]}"
		else
			if [ -z $notFirst ] && [ "$STATUS" != "ONAIR" ] && [ "${#sortedList[@]}" != 0 ]
			then
				if [ "$managerOnly" = 1 ]
				then
					msg "Last ${#sortedList[@]} manager chat(s) saved in server:\n"
				elif [ "$managerOnly" = 0 ]
				then
					msg "Last ${#sortedList[@]} chat(s) saved in server:\n"
				fi
				printf "%s\n" "${sortedList[@]}"
				break
			fi
			if [ "$managerOnly" = 1 ]
			then
				msg "Getting manager chat messages every $chatCheckInterval seconds\n"
			elif [ "$managerOnly" = 0 ]
			then
				msg "Getting every chat messages every $chatCheckInterval seconds\n"
			fi
			if [ "${#sortedList[@]}" != 0 ]
			then
				printf "%s\n" "${sortedList[@]}"
			fi
		fi
		get_status

		if [ "$STATUS" = "END" ]
		then
			break
		fi

		sleep $chatCheckInterval
		notFirst=1
	done

	if [ ${#sortedList[@]} = 0 ]
	then
		alert_msg -t "Status: $STATUS / No chats found!\n"
		exit 0
	else
		echo
		sortedList=($(printf "%s\n" "${cumulatedList[@]}" | sort -u))
		info_msg -t "Status: $STATUS (cumulatedList: ${#cumulatedList[@]} / sortedList: ${#sortedList[@]})\n"
		if [ "$managerOnly" = 1 ]
		then
			chatOutPath="${OPATH}/chat/${SHOW_ID}_${d_date}_chat.txt"
		elif [ "$managerOnly" = 0 ]
		then
			chatOutPath="${OPATH}/chat/${SHOW_ID}_${d_date}_chat_all.txt"
		fi
		n=0
		for (( i = 0; i < ${#sortedList[@]}; i++ ))
		do
			echo "${sortedList[$n]}" >> $chatOutPath
			((n++))
		done
		echo -e "\n[$(date +'%x %T')] Status: $STATUS (cumulatedList: ${#cumulatedList[@]} / sortedList: ${#sortedList[@]})\n" >> $chatOutPath
		exit 0
	fi
}

function contentget()
{
	"${wget_c[@]}" -O "${OPATH}/content/${SHOW_ID}_${d_date}_livestatus.json" ${NOW_LINK}/${SHOW_ID}/livestatus
	"${wget_c[@]}" -O "${OPATH}/content/${SHOW_ID}_${d_date}_content.json" ${NOW_LINK}/${SHOW_ID}/content
	"${wget_c[@]}" -O "${OPATH}/content/${SHOW_ID}_${d_date}.json" ${NOW_LINK}/${SHOW_ID}

	if [ -z $ITG_CHECK ]
	then
		ctlength=$(wc -c "${OPATH}/content/${SHOW_ID}_${d_date}.json" | awk '{print $1}')
		lslength=$(wc -c "${OPATH}/content/${SHOW_ID}_${d_date}_livestatus.json" | awk '{print $1}')
		msg "content: $ctlength Bytes / livestatus: $lslength Bytes"
		if [ "$ctlength" -lt 1500 ] && [ "$lslength" -lt 1000 ]
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
				"${wget_c[@]}" -O "${OPATH}/content/${SHOW_ID}_${d_date}_livestatus.json" ${NOW_LINK}/${SHOW_ID}/livestatus
				"${wget_c[@]}" -O "${OPATH}/content/${SHOW_ID}_${d_date}.json" ${NOW_LINK}/${SHOW_ID}
				ctlength=$(wc -c "${OPATH}/content/${SHOW_ID}_${d_date}.json" | awk '{print $1}')
				lslength=$(wc -c "${OPATH}/content/${SHOW_ID}_${d_date}_livestatus.json" | awk '{print $1}')
				msg "content: $ctlength Bytes / livestatus: $lslength Bytes"
				if [ "$ctlength" -lt 1500 ] && [ "$lslength" -lt 1000 ]
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
				elif [ "$ctlength" -ge 1500 ] && [ "$lslength" -ge 1000 ]
				then
					info_msg "정상 content/livestatus 파일\n"
					break
				else
					err_msg "\nERROR: contentget(): ctlength 1\n"
					content_backup
					exit 1
				fi
			done
		elif [ "$ctlength" -ge 1500 ] && [ "$lslength" -ge 1000 ]
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
	mv "${OPATH}/content/${SHOW_ID}_${d_date}_content.json" "${OPATH}/content/_ERR_${SHOW_ID}_${d_date}_${CTIME}_content.json"
	mv "${OPATH}/content/${SHOW_ID}_${d_date}_livestatus.json" "${OPATH}/content/_ERR_${SHOW_ID}_${d_date}_${CTIME}_livestatus.json"
	mv "${OPATH}/content/${SHOW_ID}_${d_date}.json" "${OPATH}/content/_ERR_${SHOW_ID}_${d_date}_${CTIME}.json"
}

function getstream()
{
	SREASON="$1"

	if [ $RETRY = 0 ]
	then
		INFO=$(jq -r .episode_description "${OPATH}/content/${SHOW_ID}_${d_date}.json")
		echo -e "Host: ${showhost}\nEP: $ep\n\n$subject\n\n$INFO" > "${OPATH}/show/$title/${d_date}_${showhost}_Info.txt"
	fi

	msg "\n방송시간: $starttime / 현재: $CTIME\n$title By ${showhost} E$ep $subject\n${OPATH}/show/$title/${FILENAME}.ts\n${url}\n"
	#-ERROR-CHECK------------------------------------------------------
	msg -t "Checking URL..."
	curl -fsS "${url}" > /dev/null 2>&1 & CURLPID=$!
	wait $CURLPID; ExitCode=$?

	if [ $ExitCode = 0 ]
	then
		info_msg -t "Valid URL, Proceeding..."
		"${ffmpeg_c[@]}" -y -headers 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3625.2 Safari/537.36? Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7? Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8? Accept-Encoding: gzip, deflate? Accept-Language: en-us,en;q=0.5?' -i "${url}" -c copy -f mpegts file:"${OPATH}/show/$title/${FILENAME}.ts" & FPID=$!
	else
		err_msg -t "Invalid URL, retrying...\n"
		contentget
		exrefresh
		timeupdate
		getstream "URL_RETRY"
	fi
	#-ERROR-CHECK------------------------------------------------------

	while [[ $(ps -p $FPID 2>/dev/null | awk 'FNR == 2 {print $4}') != 'ffmpeg' ]]
	do
		echo -en "[$(date +'%x %T')] Waiting for ffmpeg to start...\r"
		sleep 1
	done
	msg -t "Download Started, checking stream status every ${YLW}$CHKINT${NC} seconds\n"
	sleep $CHKINT

	while :
	do
		INITSIZE=$(wc -c "${OPATH}/show/$title/${FILENAME}.ts" 2>/dev/null | cut -d ' ' -f 1)
		sleep $CHKINT
		POSTSIZE=$(wc -c "${OPATH}/show/$title/${FILENAME}.ts" 2>/dev/null | cut -d ' ' -f 1)
		if [ -t 1 ]
		then
			tput el
		fi
		msg -t "INIT: ${YLW}$INITSIZE${NC} Bytes / POST: ${GRN}$POSTSIZE${NC} Bytes"
		get_status
		if [ -t 1 ]
		then
			tput el
		fi

		if [ "$STATUS" = 'ONAIR' ]
		then
			msg -t "Show Status: ${RED}$STATUS${NC}"
			if [ -t 1 ]
			then
				tput cuu 2
			fi
			if [[ $INITSIZE -eq $POSTSIZE ]]
			then
				if [ -t 1 ]
				then
					tput cud 2
				fi
				if [ "$(ps -p $FPID 2>/dev/null | awk 'FNR == 2 {print $4}')" = 'ffmpeg' ]
				then
					alert_msg -t "Download stalled, but show is still ONAIR!\n"
				elif [ "$(ps -p $FPID 2>/dev/null | awk 'FNR == 2 {print $4}')" != 'ffmpeg' ]
				then
					if [ "$MAXRETRY" = "0" ]
					then
						echo
						err_msg -t "getstream(): 다운로드 실패, 스크립트 종료\n"
						content_backup
						exit 1
					fi
					if [ "$RETRY" != "0" ]
					then
						echo
						msg -t "재시도 횟수: $RETRY / 최대 재시도 횟수: $MAXRETRY"
					fi
					if [ -z "$RETRY" ] || [ "$RETRY" -lt "$MAXRETRY" ]
					then
						((RETRY++))
						err_msg -t "$CHKINT초 동안 다운로드 중단됨, 다시 시도합니다\n"
						kill $FPID 2>/dev/null
						content_backup
						contentget
						exrefresh
						timeupdate
						getstream RETRY
					elif [ "$RETRY" -ge "$MAXRETRY" ]
					then
						echo
						err_msg -t "getstream(): 다운로드 실패\n최대 재시도 횟수($MAXRETRY회) 도달, 스크립트 종료\n"
						content_backup
						exit 1
					else
						echo
						err_msg -t "ERROR: getstream(): RETRY($RETRY/$MAXRETRY)\n"
						content_backup
						exit 1
					fi
				fi
			fi
		elif [ "$STATUS" != 'ONAIR' ]
		then
			if [ -z "$STATUS" ]
			then
				echo
				alert_msg -t "WARNING: Invalid status, retrying..."
			else
				msg -t "Show Status: ${YLW}$STATUS${NC}"
				msg -t "스트리밍 종료됨, 총 재시도 횟수: $RETRY"
				break
			fi
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
			"${ffmpeg_c[@]}" -i "${OPATH}/show/$title/${FILENAME}.ts" -vn -c:a copy "${OPATH}/show/$title/${FILENAME}.mp3"
			msg "Convert Complete: ${OPATH}/show/$title/${FILENAME}.mp3"
		elif [ "$codec" = 'aac' ]
		then
			msg "\nCodec: AAC, Saving into m4a file"
			"${ffmpeg_c[@]}" -i "${OPATH}/show/$title/${FILENAME}.ts" -vn -c:a copy "${OPATH}/show/$title/${FILENAME}.m4a"
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

	total_user=$(curl -s ${NOW_LINK}/${SHOW_ID}/livestatus | jq -r .status.indicator.cumulativeUserCount)
	msg "\n오늘 총 조회수: $total_user"

	info_msg "\nJob Finished, Code: $SREASON\n"
	exit 0 ### SCRIPT FINISH
}

function renamer()
{
	str="$1"
	str=${str//'"'/''}
	str=${str//'\r\n'/' '}
	str=${str//'\'/''}
	export $2="$str"
}

function exrefresh()
{
	unset url title startdate starttime
	content=$(cat "${OPATH}/content/${SHOW_ID}_${d_date}.json")
	livestatus=$(cat "${OPATH}/content/${SHOW_ID}_${d_date}_livestatus.json")

	showhost=$(cat "${OPATH}/content/${SHOW_ID}_${d_date}_content.json" | jq -r '.contentList[] | (.description.clova.host | join(", "))')
	vcheck=$(cat "${OPATH}/content/${SHOW_ID}_${d_date}_content.json" | jq -r .contentList[].video)
	title=$(echo "${content}" | jq -r .name)
	url=$(echo "${content}" | jq -r .hls_url)
	ORI_DATE=$(echo "${content}" | jq .start_time | xargs -i date -d {} +%s) # Seconds since 1970-01-01 00:00:00 UTC
	startdate=$(date -d @$ORI_DATE +'%y%m%d')
	starttime=$(date -d @$ORI_DATE +'%H%M%S')
	subject=$(echo "${content}" | jq .episode_name)
	ep=$(echo "${content}" | jq -r .no)
	STATUS=$(echo "${livestatus}" | jq -r .status.status) # READY | END | ONAIR

	renamer "${subject}" subject

	if [ -z "$G_USR" ]
	then
		if [ -z "${url}" ] || [ -z "$title" ] || [ -z "$startdate" ] || [ -z "$starttime" ] || [ -z "$STATUS" ]
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
			msg "\nSTARTDATE: $startdate\nSTARTTIME: $starttime\nTITLE:$title\nURL:${url}\n"
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
	TIMECHECK=$(echo "($(date -d @$ORI_DATE +%H)*60+$(date -d @$ORI_DATE +%M))-($(date +%H)*60+$(date +%M))" | bc)
	if [ "$vcheck" = 'true' ]
	then
		FILENAME="${d_date}.NAVER NOW.$title.E$ep.${subject}_VID_$CTIME"
	else
		FILENAME="${d_date}.NAVER NOW.$title.E$ep.${subject}_$CTIME"
	fi
	FILENAME=${FILENAME//'w/'/'with'}
	FILENAME=${FILENAME//'%'/'%%'}
	FILENAME=${FILENAME//'\'/''}
	alert_msg "Time variables refreshed"
}

function get_status()
{
	STATUS=$(curl -s ${NOW_LINK}/${SHOW_ID}/livestatus | jq -r .status.status)
}

function counter()
{
	TIMER=$1
	if [ "$TIMER" -gt 0 ]
	then
		echo
		echo "$TIMER초 동안 대기합니다"
		while [ "$TIMER" -gt 0 ]
		do
			if [ -t 1 ]
			then
				tput cuu1;tput el
				echo "$TIMER초 동안 대기합니다"
			fi
			sleep 1
			((TIMER--))
		done
		echo
	fi
	unset TIMER
}

function onairwait()
{
	W_TIMER=0
	FIRST=1

	while [ "$STATUS" != "ONAIR" ]
	do
		if [ "$TIMECHECK" -le -15 ]
		then
			bannerList=$(curl -s ${NOW_LINK}/bannertable)
			line=$(echo "${bannerList}" | jq .contentList[].banners[].contentId \
			     | grep -n ${SHOW_ID} | cut -d : -f 1)
			b_day=$(echo "${bannerList}" | jq -r .contentList[].banners[].time  \
			     | awk -v var=$line 'FNR == var')
			err_msg "\nERROR: 시작시간과 15분 이상 차이 발생\n금일 방송 유무를 확인해주세요"
			msg "\n쇼 이름: $title\n방송 시간: $b_day (KST)\n"
			content_backup
			exit 1
		fi

		get_status
		if [ -t 1 ] && [ $FIRST != 1 ]
		then
			for ((n = 1; n <= 6; n++))
			do
				tput cuu1; tput el
			done
		fi
		[ $FIRST = 1 ] && echo # for better logging
		timeupdate
		msg -t "Time difference: $TIMECHECK min"
		if [ "$STATUS" = "ONAIR" ]
		then
			msg -t "Live Status: ${RED}$STATUS${NC}\n"
			unset FIRST
			break
		else
			msg -t "Live Status: ${YLW}$STATUS${NC}"
		fi
		FIRST=0

		if [ "$TIMECHECK" -ge 65 ]
		then
			W_TIMER=3600
		elif [ "$TIMECHECK" -lt 65 ] # 시작 시간이 65분 미만 차이
		then
			if [ "$TIMECHECK" -gt 13 ] # 시작 시간이 13분 초과 차이
			then
				W_TIMER=600
			elif [ "$TIMECHECK" -le 13 ] # 시작 시간이 13분 이하 차이
			then
				if [ "$TIMECHECK" -gt 3 ] # 시작 시간이 3분 초과 차이
				then
					W_TIMER=60
				elif [ "$TIMECHECK" -le 3 ] # 시작 시간이 3분 이하 차이
				then
					W_TIMER=1
				fi
			fi
		fi
		counter "$W_TIMER"
	done
}

function main()
{
	contentget
	exrefresh
	timeupdate

	if [ ! -d "${OPATH}/show/$title" ]
	then
		mkdir -p "${OPATH}/show/$title"
	fi

	if [ "$vcheck" = 'true' ]
	then
		alert_msg "\n비디오 스트림 발견, 함께 다운로드 합니다\n"
	else
		alert_msg "\n비디오 스트림 없음, 오디오만 다운로드 합니다\n"
	fi

	msg "방송일  : $startdate / 오늘: ${d_date}\n방송시간: $starttime / 현재: $CTIME\n$title By ${showhost}\nE$ep $subject"

	if [ -n "$CUSTIMER" ]
	then
		alert_msg "사용자가 설정한 시작 대기 타이머가 존재합니다 ($CUSTIMER초)"
		counter $CUSTIMER
		contentget
		exrefresh
		timeupdate
	fi

	if [ -n "$FORCE" ]
	then
		getstream FORCE
	fi

	if [ "$STATUS" = "ONAIR" ]
	then
		msg "Live Status: ${RED}$STATUS${NC}"
		getstream ONAIR
	else
		onairwait
		contentget
		exrefresh
		timeupdate
		getstream WAIT
	fi
}

function get_list()
{
	package_check

	if [ -n "$isError" ]
	then
		alert_msg "You have entered unknown argument: $errArg, did you mean '$availableArg'?"
	fi

	if [ $isListLive = 1 ]
	then
		liveList=$(curl -s ${NOW_LINK}/livelist)
		idList=($(echo "$liveList" | jq -r '.liveList[] | (.contentId|tostring)'))
		IFS=$'\n'; airTimeList=($(echo "$liveList" | jq '.liveList[] | .tobe')) # https://unix.stackexchange.com/a/184866
	elif [ $isListLive = 0 ]
	then
		bannerList=$(curl -s ${NOW_LINK}/bannertable)
		idList=($(echo "$bannerList" | jq -r '.contentList[].banners[].contentId'))
		IFS=$'\n'; airTimeList=($(echo "$bannerList" | jq '.contentList[].banners[].time'))
	fi

	i=0; n=1
	for id in "${idList[@]}"
	do
		if [ $isListLive = 1 ]
		then
			echo -en "Updating live list... ($n/${#idList[@]})\r"
		elif [ $isListLive = 0 ]
		then
			echo -en "Updating banner list... ($n/${#idList[@]})\r"
		fi
		content=$(curl -s ${NOW_LINK}/${id}/content)
		title=$(echo "${content}" | jq -r .contentList[].home.title.text)
		vcheck=$(echo "${content}" | jq -r '(.contentList[].video|tostring) | sub("false"; "Audio") | sub("true"; "Video")')
		if [ -z ${airTimeList[$i]} ]
		then
			output=("${output[@]}" "$id | $vcheck | $title (Unknown)")
		else
			output=("${output[@]}" "$id | $vcheck | $title (${airTimeList[$i]//'"'/''})")
		fi
		((i++)); ((n++))
	done
	unset n i

	echo -e "\n"
	sortedOutput=($(printf "%s\n" "${output[@]}" | sort -n))
	n=1
	for (( i=0; i<${#sortedOutput[@]}; i++ ))
	do
		echo "[$n] ${sortedOutput[$i]}"
		((n++))
	done
	echo
	proceed_download
}

function proceed_download()
{
	SHOW_ID=$1
	IFS=$oriIFS
	echo -n "Do you want to start download now? (Y/N): "
	read proceed
	case "${proceed}" in
		Y|y)
			if [[ -z ${SHOW_ID} ]]
			then
				echo -n "Please enter the show ID to download (NOT LIST #!): "
				read SHOW_ID
			else
				idList=("${SHOW_ID}")
			fi

			for id in "${idList[@]}"
			do
				if [[ ${id} -eq ${SHOW_ID} ]]
				then
					get_parms -i ${SHOW_ID}
					script_init
					main
				fi
			done
			err_msg "You have entered wrong ID: ${SHOW_ID}"
			exit 255 ;;
		N|n)
			exit 0 ;;
		*)
			err_msg "Please enter Y or N"
			exit 255 ;;
	esac
}

### SCRIPT START

get_parms "$@"
script_init
main

err_msg "ERROR: EOF\n"
exit 10
