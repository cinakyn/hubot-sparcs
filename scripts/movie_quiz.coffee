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
#   hubot quiz update <from>[ <to>]- update newest quiz (매우 무거움! 날짜는 YYYY-MM-dd 형식으로)
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
NUMBER_INITIAL = ['ㅇ', 'ㅇ', 'ㅇ', 'ㅅ', 'ㅅ', 'ㅇ', 'ㅇ', 'ㅊ', 'ㅍ', 'ㄱ']
NUMBER_ANSWER = ['영', '일', '이', '삼', '사', '오', '육', '칠', '팔', '구']
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
  robot.respond /quiz update (\d{4}-\d{2}-\d{2}) ?(\d{4}-\d{2}-\d{2})?/i, (message)->
    message.send '네이버가 자주 접속하면 404를 줘서 60초에 한 주씩 업데이트하므로 매우 느립니다.'
    pg.connect(process.env.DATABASE_URL, (err, client, done)->
      return message.send err if err
      ct_query = client.query(
        '''
          CREATE TABLE IF NOT EXISTS movies(
            id            SERIAL PRIMARY KEY,
            title         CHAR(60) UNIQUE,
            reserve_per   float,
            genre         text,
            nation        CHAR(10),
            photo         CHAR(200),
            story         text,
            initials      CHAR(60),
            answer        CHAR(60)
          )
        ''', 
        (err, result)->
          done()
          return message.send err if err
          update_movie_quiz(message)
      )
    )
  
  robot.respond /quiz resanitize/i, (message)->
    message.send 're-santizing...'
    pg.connect(process.env.DATABASE_URL, (err, client, done)->
      return message.send err if err
      client.query('SELECT id, title FROM movies', (err, result)->
        for r in result.rows
          oriTitle = r.title
          id = r.id
          title = sanitize_title(oriTitle)
          initials = get_initials(title)
          answer = get_answer(title)
          client.query("UPDATE movies SET title='" + title + "', initials='" + initials + "', answer='" + answer + "' WHERE id=" + id, (err, result)->
          )
      )
    )


convertE2U = (binary_euc)->
  buf = new Buffer(binary_euc.length)
  buf.write(binary_euc, 0, binary_euc.length, 'binary')
  return translatorE2U.convert(buf).toString()

get_last_week = (date)->
  lastWeek = new Date(date.getFullYear(), date.getMonth(), date.getDate() - 7)
  return lastWeek

update_movie_quiz = (message)->
  if message.match[2]
    date = new Date(message.match[2])
  else
    date = new Date()
  from_date_split = message.match[1].split('-')
  loop_callback = ()->
    if (date.getFullYear() >= from_date_split[0] or (date.getFullYear() == from_date_split[0] and date.getMoth() + 1 >= from_date_split[1]))
      url = [
        MOVIE_NAVER_URL,
        date.getFullYear(),
        ('0' + (date.getMonth() + 1)).slice(-2),
        ('0' + date.getDate()).slice(-2)
      ].join('')
      message.send url
      m1 = {title : "극장판 포켓몬스터 베스트위시「신의 속도 게노세크트，뮤츠의 각성」", link : "http://movie.naver.com/movie/bi/mi/basic.nhn?code=109466", reserve_per : '50'}
      m2 = {title : " 수상한 VS 그녀", link : "http://movie.naver.com/movie/bi/mi/basic.nhn?code=107924", reserve_per : '50'}
      #insert_movie_list_to_db([m1, m2], message)
      message.http(url)
        .encoding('binary')
        .get() (err, response, body)->
          return message.send "http연결에 실패했습니다." + err if err 
          movie_list = parse_rank_table(body, message)
          insert_movie_list_to_db(movie_list, message)
      date = get_last_week(date)
      setTimeout(loop_callback, 60000)
  loop_callback()

parse_rank_table = (body, message)->
  html_handler = new HTMLParser.DefaultHandler((()->), ignoreWhitespace: true)
  html_parser = new HTMLParser.Parser html_handler
  html_parser.parseComplete body
  rank_table = Select(html_handler.dom, '.list_ranking')[0]
  table_rows = Select(rank_table, 'tr')
  result = []
  for tr in table_rows
    if Select(tr, 'td').length == 5
      link = MOVIE_NAVER_DOMAIN + Select(tr, '.title a')[0].attribs.href
      reserve_per = Select(tr, '.reserve_per')[0].children[0].data.slice(0, -1)
      title = convertE2U(Select(tr, '.title a')[0].attribs.title)
      m = 
        link : link 
        title : title 
        reserve_per : reserve_per 
      if m.reserve_per >= 9.0
        result.push(m)
  return result

insert_movie_list_to_db = (movie_list, message)->
  result_list = []
  callback = (detail)->
    result_list.push(detail)
    if (movie_list.length > 0)
      get_movie_detail(movie_list.pop(), message, callback)
    else
      counter = result_list.length
      pg.connect(process.env.DATABASE_URL, (err, client, done)->
        return message.send err if err
        for movie in result_list
          sql_list = ["INSERT INTO movies (title, reserve_per, genre, nation, photo, story, initials, answer) VALUES "]
          sql_list.push("('")
          sql_list.push([
            escape_sql(movie.title),
            escape_sql(movie.reserve_per),
            escape_sql(movie.genre),
            escape_sql(movie.nation),
            escape_sql(movie.photo),
            escape_sql(movie.story),
            escape_sql(movie.initials),
            escape_sql(movie.answer)
          ].join("', '"))
          sql_list.push("')")
          query = client.query(sql_list.join(''), (err, result)->
            counter -= 1
            if counter == 0
              message.send "done!"
              done()
            else
              message.send counter + "left"
            if err
              if (err.code != "23505")
                message.send JSON.stringify(err, null, '\t')
              return
#message.send JSON.stringify(result, null, '\t')
          )
      )
  get_movie_detail(movie_list.pop(), message, callback)

get_movie_detail = (movie, message, callback)->
  message.http(movie.link).get() (err, response, body)->
    return message.send "http연결에 실패했습니다." + err if err

    detail = parse_movie(body)
    detail.reserve_per = movie.reserve_per
    detail.title = sanitize_title(movie.title)
    detail.initials = get_initials(detail.title)
    detail.answer = get_answer(detail.title)
    temp = ()->
      callback(detail)
    setTimeout(temp, 10000)

parse_movie = (body)->
  html_handler = new HTMLParser.DefaultHandler((()->), ignoreWhitespace: true)
  html_parser = new HTMLParser.Parser html_handler
  html_parser.parseComplete body
  info_spec = Select(html_handler.dom, '.info_spec')[0]
  genre = parse_genre(info_spec.children[0])
  nation = Select(info_spec.children[1], 'a')[0].children[0].data
  story = parse_story(Select(html_handler.dom, '.con_tx')[0])
  photo = Select(html_handler.dom, '._Img')[0].attribs.src
  m =
    genre : genre
    nation : nation
    story : story
    photo : photo
  return m

parse_story = (story_dom)->
  result = []
  for c in story_dom.children
    if (c.type == 'tag' and c.name == 'br')
      result.push('\n')
    else
      result.push(c.data)
  return result.join('')

parse_genre = (genre_dom)->
  result = []
  for a in Select(genre_dom, 'a')
    result.push(a.children[0].data)
  return result.join(', ')

escape_sql = (str)->
  if (str)
    return str.replace(/'/g, "''")
  else
    str

sanitize_title = (title)->
  title = title.replace(/[^가-힣ㄱ-ㅎㅏ-ㅣa-zA-Z0-9]/gi, ' ')
  title = title.replace(/우리말 *녹음/gi, ' ')
  title = title.replace(/한글 *자막/gi, ' ')
  title = title.replace(/3D/g, '')
  title = title.replace(/\ +/g, ' ')
  title = title.replace(/\ $/g, '')
  title = title.replace(/^\ /g, '')
  return title

get_initials = (title)->
  initial_list = []
  for c in title
    if c.match(/[가-힣]/)
      initial_list.push(get_initial(c))
    else if c.match(/[0-9]/)
      initial_list.push(NUMBER_INITIAL[c])
    else if c.match(' ')
      initial_list.push(c)
    else if c.match(/[a-z]/i)
      initial_list.push(ALPHABET_INITIAL[c.toLowerCase()])
 
  return initial_list.join('') 

get_answer = (title)->
  answer_list = []
  for c in title 
    if c.match(/[가-힣]/)
      answer_list.push(c)
    else if c.match(/[0-9]/)
      answer_list.push(NUMBER_ANSWER[c])
    else if c.match(' ')
      continue
    else if c.match(/[a-z]/i)
      answer_list.push(ALPHABET_ANSWER[c.toLowerCase()])
 
  return answer_list.join('') 


get_initial = (c)->
  r = ((c.charCodeAt(0) - parseInt('0xac00', 16)) / 28) / 21
  t = String.fromCharCode(r + parseInt('0x1100', 16))
  return t


