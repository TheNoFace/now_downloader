#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import urllib.request
import urllib.error
import argparse
import time
import json
import ffmpeg
import sys
import os.path

version = '22.03.25'
now_link = 'https://apis.naver.com/now_web/nowapi-xhmac/nnow/v2/stream/'
bannertable_link = now_link + 'bannertable'
livelist_link = now_link + 'livelist'


def get_stream(url, name, test=False):
    name = str(path) + '\\' + name
    print('Downloading... Press Q or Ctrl+Z to quit.\nOutput: %s.ts' % name)

    if test is False:
        (
            ffmpeg
            .input(url)
            .output(name+'.ts', c='copy', f='mpegts', map='p:0')
            .overwrite_output()
            .run(capture_stderr=True)
        )
    else:
        print('\n** In Test Run **\nInput URL: %s' % url)


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


def get_list(live=False):
    if live is True:
        livelist = check_url(livelist_link, '')
        livelist_json = json.loads(livelist.read().decode('utf-8'))
        contentList, contentId = livelist_json.get('liveList'), []
        for i in range(len(contentList)):
            contentId.append(contentList[i].get('contentId'))
        sys.exit(contentId)
    else:
        bannertable = check_url(bannertable_link, '')
        bannertable_json = json.loads(bannertable.read().decode('utf-8'))
        contentList, contentId = bannertable_json.get('contentList'), []
        for i in range(len(contentList)):
            banners = contentList[i].get('banners')
            for n in range(len(banners)):
                contentId.append(banners[n].get('contentId'))
        sys.exit(contentId)


help_msg = 'Simple NOW Downloader in Python (' + version + ')'
get_msg = 'Print show info or get stream'
list_msg = 'List available shows'
parser = argparse.ArgumentParser(allow_abbrev=False, description=help_msg)
subparser = parser.add_subparsers()
parser_id = subparser.add_parser('get', description=get_msg, help=get_msg)
parser_id.add_argument('show_id', type=int, help='Show ID to download')
parser_id.add_argument('-i', '--info', action='store_true',
                       help='Print detailed show information')
parser_id.add_argument('-o', '--output-dir', type=os.path.abspath,
                       nargs='?', help='Set download dir', dest='output')
parser_id.add_argument('--test', action='store_true',
                       help='Print test information, but do not download')
parser_list = subparser.add_parser('list', description=list_msg, help=list_msg)
parser_list.set_defaults(func=get_list)
parser_list.add_argument('--live', action='store_true',
                         dest='live', help='List currently shows on air')
args = parser.parse_args()

if hasattr(args, 'func'):
    if hasattr(args, 'live'):
        get_list(args.live)
    else:
        get_list()
elif hasattr(args, 'show_id'):
    if args.output:
        path = args.output
        print('Overrided download dir: %s' % path)
    else:
        path = os.getcwd()
        print('Download dir: %s' % path)

    if args.info:
        print_info = args.info

    if args.test:
        test_run = args.test
    else:
        test_run = False

    show_id = args.show_id
else:
    sys.exit('ERROR: You have to supply get or list option')

current_time = time.strftime('%H%M%S')
current_date = time.strftime('%Y%m%d')

try:
    if bool(show_id):
        show_link = now_link + str(show_id)
except NameError:
    show_link = now_link

content_link = show_link + 'content'
livestatus_link = show_link + 'livestatus'

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

    try:
        if bool(print_info):
            ask_to_proceed()
    except NameError:
        pass

    check_url(hls_url, show_id, msg='m3u8 url', exit=True)
    get_stream(hls_url, filename, test=test_run)
