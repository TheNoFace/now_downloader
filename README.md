# Now Downloader 
Bash script to download streaming from [NAVER NOW](https://now.naver.com)   

### Discontinued (2021-09-30)
NAVER has changed streaming address information structure to hashed one, and decoding that address is well over my ability. It seems to need some proprietary javascript to decode and just re-beautifying available javascript does not help at all.

Example content from https://apis.naver.com/now_web/nowapi-xhmac/nnow/v2/stream/{ShowID}/content
```
Original: U2FsdGVkX1+IJYciNke39Up8UMOVVYynYw7/yXM8mdeAsJBAhMhXbtR7sNHJBT8Ugs+7lq7EF41igdHUBg9+FairVc+bEwyfB+wUvyzFe/EkU3EoOEnsfO+2iPRqawnudt/GP3N6IDNBOjtp96/FPPwkLLl73w/y8DpdrFqFGoA5dUOwdJkbnJzpT4jnetYduvZY5hqpk9Kd8U5B47oclL194s2i/jUk2iuELHhb9AZXTy+ctq0W8jHtzL5CW/v7cYuQHKGss9keYwPkQEoF34XLQHQEIuR58OSaoM9G7V9cTrPKKbl5/ZtrGtOKV/obDd+gl1iiG8v70gRSPbvg2viIXweNUs1yqON5W7Yj+7ku8ihMIoAa6z4tkNAbkZuIHhi21JKtSk1+94uQln/kmeuTv7WQS1XL1kxLk1b8q1BwLpuKRR4H6q9dgrR1tYB9XZNX06mq5JCFBwBDkPue4ybtqVzDZYGDZ3yzyNErFgYq8qyeG2mxDj/0NSdo+Bd4CQXWyN9nW229lBWc+KW6JmBSJQcWbpsR0HjKqRKiEuekvGOBs7rx+qs3LPIwnzYOoF3L1qPdWIGRWHjZRvWuRRKDhO/0YcKpbEKiFOEp6HIagcsdLpD6KLcw8yVj2CxUyLT/Y27iyY+QNrFRSJ9R+1HK5i0MuBKGIAcZHdBBO2FV4bLRNF6375EAhh7kVfZrCheiWmB0nzj8KEN9MSkkUDKg+rEn+vHL0m/OiAFw8Ow=
Decoded : https://livecloud.pstatic.net/now/lip2_kr/anmss0014/UiOA1cIcvKRbDDmq4WherBX3eS7bOP2AOYRWZwINnM1hWq11L90Ei0G6xfKx7W-LgezD3sv73wQtDo-BIw/playlist.m3u8?_lsu_sa_=3f19d01a080a32352d02f2346662851a0b9d3748042a29c33796f40beedb31591f8cdb46370659fbf1f23a015b2b56ff6c82f4be0894c5b022440967f327c3a9a9fb73bfd287c174aa59692258e995c9efb1035dd37601c9c6f4dd7acd2782a9939d667ba7639d1918e96db5fa2243fa1f721ccae39203deeea9243511b852cebc789a020d5fbf45df008ed93be161b28ea8647202aafcf09e59dbfc6211f107968772b2fe328e4bf8acfbb2d2fddb7e&_lsu_et_=1633177170
```

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
