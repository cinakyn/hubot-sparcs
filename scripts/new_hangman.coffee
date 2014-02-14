# Description:
#   None
#
# Dependencies:
#   "htmlparser": "1.7.6"
#   "soupselect": "0.2.0"
#   "pg": "0.6.15"
#
# Configuration:
#   None
#
# Commands:
#   hubot hangman start - start hangman game
#   hubot hangman <character> - guess answer
#   hubot hangman <word> - guess answer
#
# Author:
#   bbashong

Select      = require( "soupselect" ).select
HTMLParser  = require "htmlparser"
Iconv       = require('iconv').Iconv
pg          = require('pg')
gameDic = {}
WORD_SRC = "http://wordbook.daum.net/user/info.do?userid=bI3zBpnFVAU.&page="
WORD_SRC_PAGES = [5..10]

module.exports = (robot)->
  robot.respond /hangman make db/i, (message)->
    pg.connect process.env.DATABASE_URL, (err, client, done)->
      return message.send err if err
      ct_query = client.query(
        '''
          CREATE TABLE IF NOT EXISTS words(
            id            SERIAL PRIMARY KEY,
            word          CHAR(60),
            mean          CHAR(100)
          )
        ''',
        (err, result)->
          done()
          return message.send err if err
          makeDB(message)
      )

makeDB = (message)->
  for i in WORD_SRC_PAGES
    f = ()->
      url = WORD_SRC + i
      message.http(url).get() (err, response, body)->
        return message.send "http연결에 실패했습니다." + err if err
        parseWordbookList(message, i, body)
    setTimeout(f, i * 20000)

parseWordbookList = (message, i, body)->
  html_handler = new HTMLParser.DefaultHandler((()->), ignoreWhitespace: true)
  html_parser = new HTMLParser.Parser html_handler
  html_parser.parseComplete body
  anchor_list = Select(html_handler.dom, '.td_book a')
  count = anchor_list.length
  loop_count = 0
  if i == 5
    loop_count = 7
  sub_loop = ()->
    if (loop_count < count)
      anchor = anchor_list[loop_count]
      loop_count += 1
      wordbook_url = "http://wordbook.daum.net" + anchor.attribs.href
      page = 1
      requestWordbookPage(message, wordbook_url, page)
      setTimeout(sub_loop, 20000)
  sub_loop()

requestWordbookPage = (message, wordbook_url, page)->
  message.http(wordbook_url + '&page=' + page).get() (err, response, body)->
    return message.send "http연결에 실패했습니다." + err if err
    parseWordbookPage message, body, page, ()->
      setTimeout((()->requestWordbookPage(message, wordbook_url, page + 1)), 1000)

parseWordbookPage = (message, body, page, callback)->
  html_handler = new HTMLParser.DefaultHandler((()->), ignoreWhitespace: true)
  html_parser = new HTMLParser.Parser html_handler
  html_parser.parseComplete body
  currentPage = Select(html_handler.dom, 'em.btn_page')[0].children[0].data
  if currentPage < page
    return
  word_list = Select(html_handler.dom, '.wrap_word')
  count = word_list.length
  pg.connect process.env.DATABASE_URL, (err, client, done)->
    return message.send err if err
    for w in word_list
      word = Select(w, '.link_wordbook')[0].children[0].data
      mean = Select(w, '.link_mean')[0].children[0].data
      message.send word
      client.query "INSERT INTO words (word, mean) VALUES ('" + word + "', '" + mean + "')", (err, result)->
        count -= 1
        if count == 0
          done()
  callback()

