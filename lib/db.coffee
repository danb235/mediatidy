sqlite3 = require("sqlite3").verbose()
async = require 'async'

class Database
  dbSetup: (callback) ->
    db = new sqlite3.Database('data.db')
    db.run "CREATE TABLE IF NOT EXISTS FILES (path TEXT UNIQUE, tag TEXT, filename TEXT,
      filtered_filename TEXT, width INT, height INT, size INT, duration INT)", ->
      db.close ->
        callback()

  dbBulkFileAdd: (array, callback) ->
    db = new sqlite3.Database('data.db')

    # prepare sql statement
    stmt = db.prepare("INSERT OR IGNORE INTO FILES (path, tag) VALUES (?,?)")
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
    stmt = db.prepare("DELETE FROM FILES WHERE path=?")
    arrayLength = array.length
    i = 0
    while i < arrayLength
      stmt.run array[i].path
      i++

    # insert data into db
    stmt.finalize
    db.close ->
      callback arrayLength

  dbBulkFileGet: (callback) ->
    db = new sqlite3.Database('data.db')
    db.all "SELECT rowid AS id, path, tag, filename, filtered_filename, width,
      height, size, duration FROM FILES", (err, rows) ->
      db.close ->
        callback rows

  dbBulkNewFileGet: (callback) ->
    db = new sqlite3.Database('data.db')
    db.all "SELECT rowid AS id, path, tag, filename, filtered_filename, width,
      height, size, duration FROM FILES WHERE tag=\'VIDEO\'", (err, rows) ->
      db.close ->
        callback rows

  dbBulkFileUpdate: (array, callback) ->
    db = new sqlite3.Database('data.db')

    # prepare sql  statement
    stmt = db.prepare("UPDATE FILES SET tag=?, filename=?,
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

module.exports = Database
