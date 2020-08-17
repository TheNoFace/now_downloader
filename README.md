# Now-Downloader

Bash script to download streaming from [Naver NOW](https://now.naver.com)   
Version: 1.2.1

### Required packages
- bc
- curl
- jq
- youtube-dl
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
  -c  | --custimer [seconds]  Custom sleep timer before starting script
                              WARNING: Mandatory if today is not the broadcasting day
Notes:
  - Short options should not be grouped. You must pass each parameter on its own.
  - Disabling flags priors than setting flags

Example:
* now.sh -i 495 -o /home/ubuntu/now -r 100 -t 3000 -c 86400
  - Override output directory to /home/ubuntu/now
  - Wait 86400 seconds (24hr) before starting this script
  - Download #495 show
  - Retries 100 times if download fails
  - Retries if total stream time is less than 3000 seconds
* now.sh -i 495 -f -dr -dt -k
  - Do not retry download even if download fails
  - Do not check stream duration
  - Download #495 show immediately without checking time
  - Do not delete original audio stream file after download finishes
```