# Description:
#   None
#
# Dependencies:
#  None
#
# Configuration:
#   None
#
# Commands:
#   hubot bb start - 숫자 야구 게임 시작
#   hubot bb <number> - 정답 추측
#
# Author:
#   bbashong

gameDic = {}

module.exports = (robot)->
  robot.respond /bb start/i, (message)->
    start_baseball(message)
  
  robot.respond /bb (\d{3})/i, (message)->
    guess(message)

  robot.respond /bb test/i, (message)->
    guess(message)
class Game


  constructor: () ->
    @startTime = new Date()
    @guessCount = 0
    @magicNumber = []
    for i in [0..2]
      n = Math.floor(Math.random() * 10)
      while @magicNumber.indexOf(n) >= 0
        n = Math.floor(Math.random() * 10)
      @magicNumber.push(n)

  guess: (number) ->
    @guessCount += 1
    strike = 0
    ball = 0
    number = number + ''
    numberArr = number.split('')
    for i in [0..2]
      numberArr[i] = parseInt(numberArr[i])

    for i in [0..2]
      if numberArr.indexOf(numberArr[i]) != i
        return {strike : -1, ball : -1}

    for i in [0..2]
      if numberArr[i] == @magicNumber[i]
        strike += 1
      else if @magicNumber.indexOf(numberArr[i]) >= 0
        ball += 1
    return {strike : strike, ball : ball}

start_baseball = (message) ->
  room = message.message.user.room
  gameDic[room] = new Game()
  message.send "숫자 야구 준비 완료!"

guess = (message) ->
  room = message.message.user.room
  game = gameDic[room]
  if not game
    return message.send '진행중인 게임이 없습니다.'
  result = game.guess(message.match[1], message)
  if result.strike == 3
    elapsedTime = ((new Date()).getTime() - game.startTime.getTime()) / 1000
    message.send message.message.user.name + '님 축하합니다, 승리하셨습니다! (총 시도 횟수 : ' + game.guessCount + '회, 걸린 시간 : ' + elapsedTime + '초)'
    gameDic[room] = undefined
  else if result.strike < 0
    message.send '서로 다른 3개의 숫자만 유효합니다.'
  else
    message.send '(' + game.guessCount + '회) 스트라이크 ' + result.strike + '개, 볼 ' + result.ball + '개'

