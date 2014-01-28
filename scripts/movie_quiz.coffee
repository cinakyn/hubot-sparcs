# Description:
#   None
#
# Dependencies:
#   "htmlparser": "1.7.6"
#   "soupselect": "0.2.0"
#
# Configuration:
#   None
#
# Commands:
#   hubot quiz - start movie quiz
#   hubot quiz update - update newest quiz (HEAVY)
#   hubot quiz pass - pass the quiz
#   hubot quiz hint - get hint
#   hubot quiz <answer> - test which answer is correct or not
#
# Author:
#   bbashong

Select      = require( "soupselect" ).select
HTMLParser  = require "htmlparser"
MOVIE_NAVER_URL = "http://movie.naver.com/movie/sdb/rank/rreserve.nhn?date="
UPDATE_START_YEAR = '2013'

module.exports = (robot)->
  robot.respond /quiz update/i, (message)->
    update_movie_quiz(message)

get_last_week = (date)->
  lastWeek = new Date(date.getFullYear(), date.getMonth(), date.getDate() - 7)
  return lastWeek

update_movie_quiz = (message)->
  date = new Date()
  while (date.getFullYear() >= UPDATE_START_YEAR)
    date = get_last_week(date)
    url = [
      MOVIE_NAVER_URL,
      date.getFullYear(),
      ('0' + (date.getMonth() + 1)).slice(-2),
      ('0' + date.getDate()).slice(-2)
    ].join('')
    message.send url
    date = get_last_week(date)
    message.http(url).get() (error, response, body)->
      return message.send "http연결에 실패했습니다." + error if error 
      parse_rank_table(body, message)
    date = get_last_week(date)

parse_rank_table = (body, message) ->
  html_handler = new HTMLParser.DefaultHandler((()->), ignoreWhitespace: true)
  html_parser = new HTMLParser.Parser html_handler
  html_parser.parseComplete body
  rank_table = Select(html_handler.dom, '.list_ranking')[0]
  table_rows = Select(rank_table, 'tr')
  result = []
  for tr in table_rows
    if Select(tr, 'td').length == 5
      m = 
        link : Select(tr, '.title a')[0].attribs.href
        title : Select(tr, '.title a')[0].attribs.title
        reserve_per : Select(tr, '.reserve_per')[0].children[0].data.slice(0, -1)
      message.send m.link
      message.send m.title
      message.send m.reserve_per
      






