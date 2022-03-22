# Now Downloader
Simple python program to download streaming from [NAVER NOW](https://now.naver.com)   
Python version is still in development, and only few options are available comparing to shell script version.
Please check out shell script version: [Bash branch](https://github.com/TheNoFace/now_downloader/tree/master)

### Required Python Module/Executable
- [ffmpeg](https://ffmpeg.org/)
- [ffmpeg-python](https://github.com/kkroening/ffmpeg-python)

### How to use
```
usage: now.py [-h] [-i] [-o [OUTPUT_DIR]] show_id

Simple NOW Downloader in Python (22.03.21)

positional arguments:
  show_id               Show ID to download

optional arguments:
  -h, --help            show this help message and exit
  -i, --info            Print detailed show information
  -o [OUTPUT_DIR], --output_dir [OUTPUT_DIR]
                        Set download destination
```
