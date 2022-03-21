import urllib.request
import urllib.error
import argparse
import time
import json
import ffmpeg

parser = argparse.ArgumentParser(description='Simple NOW Downloader in Python')
parser.add_argument('show_id', type=int, help='Show ID to download')
args = parser.parse_args()

now_link = 'https://apis.naver.com/now_web/nowapi-xhmac/nnow/v2/stream/'
current_time = time.strftime('%H%M%S')
current_date = time.strftime('%Y%m%d')

show_id = args.show_id
show_link = now_link + str(show_id)
content_link = show_link + '/content'
livestatus_link = show_link + '/livestatus'
try:
    show_json_response = urllib.request.urlopen(show_link)
except urllib.error.HTTPError as e:
    print('Stream information of ID %d is not accessible (Error Code: %d)' %
          (show_id, e.code))
else:
    show_json = json.loads(show_json_response.read().decode('utf-8'))
    hls_url = show_json.get('hls_url')
    show_name = show_json.get('name')
    show_ep = str(show_json.get('no'))
    show_title = show_json.get('episode_name').replace('\r\n', ' ')
    show_info = show_json.get('episode_description')
    filename = current_date + '.NAVER NOW.' + show_name + \
        '.E' + show_ep + '.' + show_title + '_' + current_time

    print('Downloadig %s (E%s)\nTitle: %s\nFilename: %s\n%s\n\n%s'
          % (show_name, show_ep, show_title, filename, hls_url, show_info))

    (
        ffmpeg
        .input(hls_url)
        .output(filename+'.ts', c='copy', f='mpegts', map='p:0')
        .overwrite_output()
        .run(capture_stderr=True)
    )
