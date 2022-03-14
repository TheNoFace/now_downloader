# Now Downloader
Bash script to download streaming from [NAVER NOW](https://now.naver.com)   

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
  -c  | --chat                Print live or recent host/manager's chats and save into file
        --chat-all            Print live or recent chats and save into file
                              NOTE: File is saved after the show has finished (ONAIR -> END)
        --custimer [second]   Custom sleep timer before starting script
                              NOTE: Mandatory if today is not the broadcasting day
  -f  | --force               Start download immediately without any time checks
        --info                Display detailed info of the show
  -k  | --keep                Do not delete original audio stream(.ts) file after download finishes
  -l  | --list (live)         List every shows' ID and titles then exits
                              live: List shows' ID and titles that are currently on air
  -nc | --no-check            Do not check integrity of content/livestatus files in content folder
  -nr | --no-retry            Disable retries (same as -r 0)
  -o  | --output <dir>        Overrides output path to check if it's been set before
  -r  | --retry [number]      Maximum retries if download fails
                              Default is set to 10 times
  -t  | --time-check [second] Check stream status if it has ended abnormally by checking file size
                              Default is set to 30 seconds
  -u  | --user                Display current/total users of the show
  -v  | --verbose             Print wget/youtube-dl/ffmpeg messages

        --help                Show this help screen
        --version             Show program name and version

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
* now.sh -i 495 -f -nr -nc -k
  - Do not retry download even if download fails
  - Do not check integrity of content/livestatus files in content folder
  - Download #495 show immediately without checking time
  - Do not delete original audio stream file after download finishes
```
