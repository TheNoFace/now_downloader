# Now Downloader (DEV Branch)

Bash script to download streaming from [NAVER NOW](https://now.naver.com)   
**You're now on dev branch. To check out main branch, click [here](https://github.com/TheNoFace/now_downloader/tree/master)**

### Required packages

If you want to run this script using crontab, then make sure you can run below commands in crontab. (not local)

- wget
- curl
- bc
- [jq](https://stedolan.github.io/jq/)
- [youtube-dl](https://youtube-dl.org/)
- [ffmpeg](https://ffmpeg.org/)

### How to use
```
now.sh -i [ShowID] [options]

Required:
  -i  | --id [number]         ID of the show to download

Options:
  -c  | --custimer [seconds]  Custom sleep timer before starting script
                              WARNING: Mandatory if today is not the broadcasting day
        --chat                Print live or recent manager's chats and save into file
        --chatall             Print live or recent chats and save into file
  -dc | --dcont               Do not check integrity of content/livestatus files in content folder
  -dr | --dretry              Disable retries (same as -r 0)
  -f  | --force               Start download immediately without any time checks
  -h  | --help                Show this help screen
        --info                Display detailed info of show and exits
  -k  | --keep                Do not delete original audio stream(.ts) file after download finishes
  -ls | --list                List every shows' ID and titles then exits
        --list live           List shows' ID and titles that are currently on air
  -o  | --opath <dir>         Overrides output path to check if it's been set before
  -r  | --maxretry [number]   Maximum retries if download fails
                              Default is set to 10 times
  -t  | --chkint [seconds]    Check stream status if it has ended abnormally by checking file size
  -u  | --user                Display current/total users of the show
                              Default is set to 30 seconds
  -v  | --version             Show program name and version
        --verbose             Print wget/youtube-dl/ffmpeg messages
Notes:
  - Short options should not be grouped. You must pass each parameter on its own.
  - Disabling flags priors than setting flags

Example:
* now.sh -i 495 -o /home/ubuntu/now -r 100 -t 60 -c 86400
  - Override output directory to /home/ubuntu/now
  - Wait 86400 seconds (24hr) before starting this script
  - Download #495 show
  - Retries 100 times if download fails
  - Check stream status for every 60 seconds
* now.sh -i 495 -f -dr -k
  - Do not retry download even if download fails
  - Download #495 show immediately without checking time
  - Do not delete original audio stream file after download finishes
```
