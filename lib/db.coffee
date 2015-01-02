sqlite3 = require("sqlite3").verbose()
async = require 'async'

class Database

  dbSetup: (callback) ->
    db = new sqlite3.Database('data.db')

    async.series [
      (seriesCallback) ->
        db.run "CREATE TABLE IF NOT EXISTS MEDIAFILES (path TEXT UNIQUE, tag TEXT, filename TEXT,
          filtered_filename TEXT, width INT, height INT, size INT, duration INT)", ->
          seriesCallback()
      (seriesCallback) ->
        db.run "CREATE TABLE IF NOT EXISTS PATHS (path TEXT UNIQUE, tag TEXT)", ->
          seriesCallback()
    ], (err, results) ->
      db.close ->
        callback()

  dbBulkFileAdd: (array, callback) ->
    db = new sqlite3.Database('data.db')

    # prepare sql statement
    stmt = db.prepare("INSERT OR IGNORE INTO MEDIAFILES (path, tag) VALUES (?,?)")
    arrayLength = array.length
    i = 0
    while i < arrayLength
      stmt.run array[i].path, array[i].tag
      i++

    # insert data into db
    stmt.finalize
    db.close ->
      callback arrayLength

  dbBulkFileDelete: (array, callback) ->
    db = new sqlite3.Database('data.db')

    # prepare sql  statement
    stmt = db.prepare("DELETE FROM MEDIAFILES WHERE path=?")
    arrayLength = array.length
    i = 0
    while i < arrayLength
      stmt.run array[i].path
      i++

    # insert data into db
    stmt.finalize
    db.close ->
      callback arrayLength

  dbBulkFileGetAll: (callback) ->
    db = new sqlite3.Database('data.db')
    db.all "SELECT rowid AS id, path, tag, filename, filtered_filename, width,
      height, size, duration FROM MEDIAFILES", (err, rows) ->
      db.close ->
        callback rows

  dbBulkFileGetTag: (tag, callback) ->
    db = new sqlite3.Database('data.db')
    db.all "SELECT rowid AS id, path, tag, filename, filtered_filename, width,
      height, size, duration FROM MEDIAFILES WHERE tag=#{tag}", (err, rows) ->
      db.close ->
        callback rows

  dbBulkFileUpdate: (array, callback) ->
    db = new sqlite3.Database('data.db')

    # prepare sql  statement
    stmt = db.prepare("UPDATE MEDIAFILES SET tag=?, filename=?,
      filtered_filename=?, width=?, height=?, size=?,
      duration=? WHERE path=?")
    arrayLength = array.length
    i = 0
    while i < arrayLength
      stmt.run array[i].tag, array[i].filename, array[i].filtered_filename,
        array[i].width, array[i].height, array[i].size, array[i].duration,
        array[i].path
      i++

    # insert data into db
    stmt.finalize
    db.close ->
      callback arrayLength

  dbBulkPathGetAll: (callback) ->
    db = new sqlite3.Database('data.db')
    db.all "SELECT rowid AS id, path, tag FROM PATHS", (err, rows) ->
      db.close ->
        callback rows

  dbPathAdd: (path, tag, callback) ->
    db = new sqlite3.Database('data.db')

    # prepare sql statement
    stmt = db.prepare("INSERT OR IGNORE INTO PATHS (path, tag) VALUES (?,?)")
    stmt.run path, tag

    # insert data into db
    stmt.finalize
    db.close ->
      callback()

module.exports = Database
