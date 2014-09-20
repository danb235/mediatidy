sqlite3 = require("sqlite3").verbose()


class Data
  constructor: (@files, @dirs) ->

  createDb: (callback) ->
    console.log "createDb chain"
    db = new sqlite3.Database('data.db')
    db.run "CREATE TABLE IF NOT EXISTS FILES (path TEXT, filename TEXT, width NUM, height NUM)"
    db.close ->
      callback()

  insertRows: (files, dirs) ->
    db = new sqlite3.Database('data.db')
    data = new Data
    data.createDb ->
      console.log "insertRows Ipsum i"
      stmt = db.prepare("INSERT INTO FILES (path) VALUES (?)")

      console.log files.length, dirs.length
      arrayLength = files.length
      i = 0

      while i < arrayLength
        stmt.run files[i]
        i++
      stmt.finalize data.readAllRows

  readAllRows: ->
    db = new sqlite3.Database('data.db')
    console.log "readAllRows lorem"
    data = new Data
    db.all "SELECT rowid AS id, path FROM FILES", (err, rows) ->
      rows.forEach (row) ->
        console.log row.id + ": " + row.path
      data.closeDb()

  closeDb: ->
    db = new sqlite3.Database('data.db')
    console.log "closeDb"
    db.close()

module.exports = Data
