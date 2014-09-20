Data = require '../lib/data'
colors = require('colors')
dir = require('node-dir')


class Movies
  constructor: (@path) ->

  update: (callback) ->
    response = 'donedone'
    console.log "==> ".cyan.bold + "Looking for files in " + @path + "..."

    # Get all files and directories in user defined path
    dir.paths @path, (err, paths) ->
      throw err  if err
      console.log "files:", paths.files.length
      console.log "subdirs:", paths.dirs.length

      data = new Data paths.files, paths.dirs
      data.insertRows paths.files, paths.dirs, (dataresponse) ->
        console.log dataresponse
        callback? response

module.exports = Movies
