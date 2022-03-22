import urllib.request
import urllib.error
import argparse
import time
import json
import ffmpeg
import sys

version = '22.03.21'
help_msg = 'Simple NOW Downloader in Python (' + version + ')'

parser = argparse.ArgumentParser(allow_abbrev=False,
                                 description=help_msg)
parser.add_argument('show_id', type=int, help='Show ID to download')
parser.add_argument('-i', '--info', action='store_true',
                    help='Print detailed show information')
args = parser.parse_args()

print_info = args.info
now_link = 'https://apis.naver.com/now_web/nowapi-xhmac/nnow/v2/stream/'
current_time = time.strftime('%H%M%S')
current_date = time.strftime('%Y%m%d')

show_id = args.show_id
show_link = now_link + str(show_id)
bannertable_link = now_link + '/bannertable'
livelist_link = now_link + '/livelist'
content_link = show_link + '/content'
livestatus_link = show_link + '/livestatus'


def get_stream(url, name):
    print('Downloading... (%s.ts)' % name)
    (
        ffmpeg
        .input(url)
        .output(name+'.ts', c='copy', f='mpegts', map='p:0')
        .overwrite_output()
        .run(capture_stderr=True)
    )


def check_url(url, id, no_msg=False, msg=False, exit=False):
    if msg:
        text = msg + ' of show ID %d is not accessible (%d)'
    else:
        text = 'URL of show ID %d is not accessible (%d)'

    try:
        if not url:
            sys.exit(print('ERROR: hls_url is empty!', file=sys.stderr))
        response = urllib.request.urlopen(url)
    except urllib.error.HTTPError as e:
        if no_msg is False:
            print(text % (show_id, e.code), file=sys.stderr)
        if exit is True:
            sys.exit()
        else:
            pass
    except urllib.error.URLError as e:
        if no_msg is False:
            print(text % (show_id, e.reason), file=sys.stderr)
        if exit is True:
            sys.exit()
        else:
            pass
    else:
        return response


def ask_to_proceed():
    choice = input('Proceed to download? (Y/N): ')
    y_list = ('y', 'Y', 'yes', 'Yes', 'YES')
    if choice not in y_list:
        sys.exit(0)
    else:
        pass


show_json_response = check_url(show_link, show_id, exit=True)
if show_json_response:
    show_json = json.loads(show_json_response.read().decode('utf-8'))
    hls_url = show_json.get('hls_url')
    show_name = show_json.get('name')
    show_ep = str(show_json.get('no'))
    show_title = show_json.get('episode_name').replace('\r\n', ' ')
    show_info = show_json.get('episode_description')
    filename = current_date + '.NAVER NOW.' + show_name + \
        '.E' + show_ep + '.' + show_title + '_' + current_time

    print('%s (E%s)\nTitle: %s\n%s\n\n%s\n'
          % (show_name, show_ep, show_title, hls_url, show_info))

    if print_info is True:
        ask_to_proceed()

    check_url(hls_url, show_id, msg='m3u8 url', exit=True)
    get_stream(hls_url, filename)
