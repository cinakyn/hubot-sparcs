# Description:
#   None
#
# Dependencies:
#   "htmlparser": "1.7.6"
#   "soupselect": "0.2.0"
#   "iconv": "~2.0.7"
#   "pg": "0.6.15"
#
# Configuration:
#   None
#
# Commands:
#   hubot quiz - start movie quiz
#   hubot quiz update <from> - update newest quiz (매우 무거움! from은 YYYY-MM-dd 형식으로)
#   hubot quiz pass - pass the quiz
#   hubot quiz hint - get hint
#   hubot quiz <answer> - test which answer is correct or not
#
# Author:
#   bbashong

Select      = require( "soupselect" ).select
HTMLParser  = require "htmlparser"
Iconv       = require('iconv').Iconv
pg          = require('pg')
translatorE2U = new Iconv('euc-kr', 'utf-8')
MOVIE_NAVER_URL = "http://movie.naver.com/movie/sdb/rank/rreserve.nhn?date="
MOVIE_NAVER_DOMAIN = "http://movie.naver.com"
NUMBER_INITIAL = ['ㅇ', 'ㅇ', 'ㅅ', 'ㅅ', 'ㅇ', 'ㅇ', 'ㅊ', 'ㅍ', 'ㄱ']
NUMBER_ANSWER = ['일', '이', '삼', '사', '오', '육', '칠', '팔', '구']
ALPHABET_INITIAL= 
  a : 'ㅇㅇ'
  b : 'ㅂ'
  c : 'ㅆ'
  d : 'ㄷ'
  e : 'ㅇ'
  f : 'ㅇㅍ'
  g : 'ㅈ'
  h : 'ㅇㅇㅊ'
  i : 'ㅇㅇ'
  j : 'ㅈㅇ'
  k : 'ㅋㅇ'
  l : 'ㅇ'
  m : 'ㅇ'
  n : 'ㅇ'
  o : 'ㅇ'
  p : 'ㅍ'
  q : 'ㅋ'
  r : 'ㅇ'
  s : 'ㅇㅅ'
  t : 'ㅌ'
  u : 'ㅇ'
  v : 'ㅂㅇ'
  w : 'ㄷㅂㅇ'
  x : 'ㅇㅅ'
  y : 'ㅇㅇ'
  z : 'ㅈ'
ALPHABET_ANSWER= 
  a : '에이'
  b : '비'
  c : '씨'
  d : '디'
  e : '이'
  f : '에프'
  g : '지'
  h : '에이치'
  i : '아이'
  j : '제이'
  k : '케이'
  l : '엘'
  m : '엠'
  n : '엔'
  o : '오'
  p : '피'
  q : '큐'
  r : '알'
  s : '에스'
  t : '티'
  u : '유'
  v : '브이'
  w : '더블유'
  x : '엑스'
  y : '와이'
  z : '지'

module.exports = (robot)->
  robot.respond /test/i, (message)->
    html_handler = new HTMLParser.DefaultHandler((()->), ignoreWhitespace: true)
    html_parser = new HTMLParser.Parser html_handler
    html_parser.parseComplete '<div>asdf<br>efg<br>gig</div>'
    message.send JSON.stringify(html_handler.dom)
