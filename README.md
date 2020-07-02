# Now-Downloader

Bash script to download streaming from [Naver NOW](https://now.naver.com)
Current version: 1.0.1 (20200702)

### Required packages
- bc
- youtube-dl
- ffmpeg

### Usage
```
now.sh -i [ShowID] [options]

Required:
  -i | --id [number]         ID of the show to download

Options:
  -v | --version             Show program name and version
  -h | --help                Show this help screen
  -f | --force               Start download immediately without any time checks
  -o | --opath <dir>         Overrides output path if it's been set before
  -r | --MAXRETRY [number]   Maximum retries if download fails
                             Default is set to 10 (times)
  -t | --PTIMETH [seconds]   Failcheck threshold if the stream has ended abnormally
                             Default is set to 3300 (seconds)
  -c | --CUSTIMER [seconds]  Custom sleep timer before starting script
                             WARNING: Mandatory if today is not the broadcasting day
Notes:
  - Short options should not be grouped. You must pass each parameter on its own.

Example:
  now.sh -i 495 -f -o /home/ubuntu/now  -r 100 -t 3000 -c 86400
  - Override output directory to /home/ubuntu/now
  - Wait 86400 seconds (24hr) before starting this script
  - Download #495 show
  - Retries 100 times if download fails
  - Retries if total stream time is less than 3000 seconds
```