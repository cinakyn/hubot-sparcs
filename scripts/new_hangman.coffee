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
STATUS_1 = '''
.     _______
.    |/      |
.    |      (_)
.    |      \\|/
.    |        |
.    |      / \\
.    |
.__|___
\n\n
'''

module.exports = (robot)->
  robot.respond /hangman make db/i, (message)->
    pg.connect process.env.DATABASE_URL, (err, client, done)->
      return message.send err if err
      ct_query = client.query(
        '''
          CREATE TABLE IF NOT EXISTS words(
            id            SERIAL PRIMARY KEY,
            word          CHAR(60) UNIQUE,
            mean          CHAR(100)
          )
        ''',
        (err, result)->
          done()
          return message.send err if err
          makeDB(message)
      )
  robot.respond /hangman start$/i, (message)->
    start_game(message)

  robot.respond /hangman ([a-z])$/i, (message)->
    guessWord(message)

  robot.respond /hangman ((?!start).{2,})$/i, (message)->
    guessWord(message)

class Game
  constructor: (@word, @mean)->
    @openedCharacter = []
    @wordArr = @word.split('')
    @remainChances = 9
    @openStatus = []
    for c in @wordArr
      if c.match(/[a-z]/i)
        @openStatus.push(false)
      else
        @openStatus.push(true)

  checkEnd: ()->
    for b in @openStatus
      if !b
        return false
    return true
  
  cleanWord: (word)->
    return word.replace(/[^a-z]/gi, '')

  guessCharacter: (message, c)->
    user = message.message.user.name

    if @openedCharacter.indexOf(c) >= 0
      message.send user + '은(는) 바보인가요? 이미 ' + c + '는 말한 적이 있잖아요.\n 한번 봐드릴테니 다시하세요.\n' + @strStatus()
      return false
    @openedCharacter.push(c)
    if @wordArr.indexOf(c) >= 0
      for w, i in @wordArr
        if @wordArr[i] == c
          @openStatus[i] = true
      if @checkEnd()
        message.send user + '님 축하합니다. 마지막 글자를 맞추셨습니다!\n' + @strStatus()
        return true
      else
        message.send '네! 이 단어는 ' + c + '를 포함하고 있습니다.\n' + @strStatus()
        return false
    else 
      @remainChances -= 1
      if @remainChances > 0
        message.send '이 단어는 ' + c + '를 포함하고 있지 않습니다. 당신의 친구가 죽어갑니다.(남은 기회 ' + @remainChances + '번)\n' + @strStatus()
        return false
      else
        message.send '당신의 친구가 죽었습니다. 정답은 ' + @word + '입니다.'
        return true


  guessWord: (message, guessWord)->
    user = message.message.user.name
    if @cleanWord(guessWord) == @cleanWord(@word)
      message.send user + '님 축하합니다. 정답을 맞추셨습니다!'
      return true
    else
      @remainChances -= 1
      message.send '정답이 아닙니다. 당신의 친구가 죽어갑니다.(남은 기회 ' + @remainChances + '번)\n' + @strStatus()
      return false

  strStatus: ()->
    result = ''
    result += STATUS_1
    status = []
    for w, i in @wordArr
      if @openStatus[i]
        status.push(@wordArr[i])
      else
        status.push('_')
    result += status.join('|')
    result += '\n'
    return result

start_game = (message)->
  pg.connect process.env.DATABASE_URL, (err, client, done)->
    return message.send err if err
    client.query 'SELECT * FROM words ORDER BY random() LIMIT 200', (err, result)->
      message.send err if err
      row = result.rows[Math.floor(Math.random() * result.rows.length)]
      game = new Game(
        row.word.replace(/\ *$/gi, ''),
        row.mean.replace(/\ *$/gi, '')
      )
      done()
      room = message.message.user.room
      gameDic[room] = game
      str = game.strStatus(message)
      str += game.mean
      message.send str
      message.send game.word

guessWord = (message)->
  room = message.message.user.room
  game = gameDic[room]
  if message.match[1].length > 1
    end = game.guessWord(message, message.match[1])
  else 
    end = game.guessCharacter(message, message.match[1])
  if end
    gameDic[roo] = undefined

makeDB = (message)->
  i = 0
  f = ()->
    if i >= WORD_SRC_PAGES.length
      return
    url = WORD_SRC + WORD_SRC_PAGES[i]
    message.http(url).get() (err, response, body)->
      return message.send "http연결에 실패했습니다." + err if err
      message.send '(parseWordbook)' + url
      parseWordbookList(message, WORD_SRC_PAGES[i], body)
    i += 1
    setTimeout(f, 200000)
  f()

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
  message.send '(request page)' + wordbook_url + '&page=' + page
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
      client.query "INSERT INTO words (word, mean) VALUES ('" + word + "', '" + mean + "')", (err, result)->
        count -= 1
        if count == 0
          done()
  callback()

