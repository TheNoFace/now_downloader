# Now Downloader

Bash script to download streaming from [NAVER NOW](https://now.naver.com)   
Version: 1.3.4

### Required packages

If you want to run this script using crontab, then make sure you can run below commands in crontab. (not local)

- bc
- [jq](https://stedolan.github.io/jq/)
- [youtube-dl](https://youtube-dl.org/)
- ffmpeg

### How to use
```
now.sh -i [ShowID] [options]

Required:
  -i  | --id [number]         ID of the show to download

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
                              Default is set to 10 times
  -dr | --dretry              Disable retries (same as -r 0)
  -t  | --chkint [seconds]    Check stream status if it has ended abnormally by checking file size
                              Default is set to 30 seconds
  -c  | --custimer [seconds]  Custom sleep timer before starting script
                              WARNING: Mandatory if today is not the broadcasting day
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
