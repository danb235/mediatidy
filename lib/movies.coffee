
class Albums
  constructor: (@accessToken, @apiUrl, @album) ->
    @requestData =
      url: "#{@apiUrl}/3/albums.json"
      json: true
      form:
        name: album
      headers:
        Authorization: "Bearer #{accessToken}"

  get: (callback) ->
    data =
      url: if @album is 0 then "#{@apiUrl}/3/albums.json" else "#{@apiUrl}/3/albums/#{@album}/files.json"
      json: true
      headers:
        Authorization: "Bearer #{@accessToken}"

    request.get data, (error, response, body) ->
      callback? response, body

  post: (callback) ->
    request.post @requestData, (error, response, body) ->
      unless error? then callback? body else callback? error

module.exports = Albums
