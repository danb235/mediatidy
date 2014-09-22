dir = require('node-dir')
sqlite3 = require("sqlite3").verbose()

class Movies
  constructor: (@path) ->

  dbRead: (callback) ->
    console.log 'retrieving files from database...'

    # read all rows from the files table
    files = []
    db = new sqlite3.Database('data.db')
    db.all "SELECT rowid AS id, path FROM FILES", (err, rows) ->
      rows.forEach (row) ->
        files.push(row.id + ": " + row.path)
      db.close ->
        callback? files

  dbUpdate: (files, dirs, callback) ->
    console.log 'updating database with latest files and directories...'

    # create db and tables; add any files not already in db
    db = new sqlite3.Database('data.db')
    db.run "CREATE TABLE IF NOT EXISTS FILES (path TEXT UNIQUE, filename TEXT, width NUM, height NUM)", ->

      # prepare sql statement
      stmt = db.prepare("INSERT OR IGNORE INTO FILES (path) VALUES (?)")

      # iterate through array of files to construct sql statement
      arrayLength = files.length
      i = 0
      while i < arrayLength
        stmt.run files[i]
        i++

      # insert data into db
      stmt.finalize
      db.close ->
        console.log 'database updated...'
        callback? true

  update: (callback) ->
    console.log 'looking for files and directories at', @path, '...'
    path = @path
    dir.paths path, (err, paths) ->
      console.log  "found " + paths.files.length + ' files and ' + paths.dirs.length + ' directories...'
      callback? paths.files, paths.dirs

module.exports = Movies
