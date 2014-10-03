dir = require('node-dir')
sqlite3 = require("sqlite3").verbose()
sha1 = require("node-sha1")
fs = require('fs-extra')
probe = require('node-ffprobe')
async = require('async')
colors = require 'colors'
hash_file = require("hash_file")

class Movies
  constructor: (@path) ->

  dbRead: (callback) ->
    console.log '==> '.cyan.bold + 'read from database'

    # read all rows from the files table
    db = new sqlite3.Database('data.db')
    db.all "SELECT rowid AS id, filtered_filename, signature, width, height, path, status FROM FILES", (err, rows) ->
      rows.forEach (row) ->
        console.log row.id, row.status, row.filtered_filename, row.signature, row.width, row.height, row.path
      db.close ->
        console.log 'Total files: ' + rows.length + '...'
        callback()

  dbExists: (callback) ->
    console.log '==> '.cyan.bold + 'removing files and directories from database that no longer exist'

    db = new sqlite3.Database('data.db')
    async.series [
      (callback) ->
        db.all "SELECT rowid AS id, path, status FROM FILES", (err, rows) ->
          rowsLength = rows.length
          removedFiles = 0
          fileExist = (iteration) ->
            fs.exists rows[iteration].path, (exists) ->
              if exists is false
                console.log 'MISSING FILE:'.yellow, rows[iteration].path
                stmt = db.prepare("DELETE FROM FILES WHERE path=?")
                stmt.run rows[iteration].path
                stmt.finalize
                console.log 'REMOVED FROM DB:'.yellow, rows[iteration].path
                removedFiles++
              if rowsLength is iteration + 1
                console.log removedFiles + ' out of ' + rowsLength + ' files removed from database...'
                callback()
              else
                fileExist(iteration + 1)
          if rowsLength > 0
            fileExist(0)
          else
            console.log 'No files in database to check...'
            callback()
      (callback) ->
        db.all "SELECT rowid AS id, path FROM DIRS", (err, rows) ->
          rowsLength = rows.length
          removedDirs = 0
          dirExist = (iteration) ->
            fs.exists rows[iteration].path, (exists) ->
              if exists is false
                console.log 'MISSING DIR:'.yellow, rows[iteration].path
                stmt = db.prepare("DELETE FROM DIRS WHERE path=?")
                stmt.run rows[iteration].path
                stmt.finalize
                console.log 'REMOVED FROM DB:'.yellow, rows[iteration].path
                removedDirs++
              if rowsLength is iteration + 1
                console.log removedDirs + ' out of ' + rowsLength + ' directories removed from database...'
                callback()
              else
                dirExist(iteration + 1)
          if rowsLength > 0
            dirExist(0)
          else
            console.log 'No directories in database to check...'
            callback()
    # optional callback
    ], (err, results) ->
      db.close ->
        console.log 'finished removing missing files and directories from mediatidy database'
        callback? true

  dbFileMetaUpdate: (callback) ->
    console.log '==> '.cyan.bold + 'update database with probed video metadata'

    db = new sqlite3.Database('data.db')
    db.all "SELECT rowid AS id, path, status FROM FILES WHERE status=\'no_meta\'", (err, rows) ->
      rowsLength = rows.length
      console.log 'Found: ' + rowsLength + ' video files that need metadata update'
      corruptFiles = 0
      probeFiles = (iteration) ->
        probe rows[iteration].path, (err, probeData) ->

          # loop through streams to find video stream
          if typeof probeData is "undefined" or probeData["streams"].length is 0
            stmt = db.prepare("UPDATE FILES SET status=? WHERE path=?")
            stmt.run 'corrupt', rows[iteration].path
            stmt.finalize
            probeFiles(iteration + 1)
          else if probeData.filename.match(/sample/i)
            stmt = db.prepare("UPDATE FILES SET status=? WHERE path=?")
            stmt.run 'sample', rows[iteration].path
            stmt.finalize
            probeFiles(iteration + 1)
          else if probeData["streams"].length > 0

            # create filtered filename: remove file extension;
            # remove whitespace; remove special characters;
            # remove 'year' and all text after; all uppercase
            filteredFileName = probeData.filename.replace(/\.\w*$/, "")
            filteredFileName = filteredFileName.replace(/\s/g, "")
            filteredFileName = filteredFileName.replace(/\W/g, "")
            filteredFileName = filteredFileName.replace(/\d{4}.*$/g, "")
            filteredFileName = filteredFileName.toUpperCase()

            # get file signature from first and last 256 bytes of data
            fileSigGen = (filePath, callback) ->
              beginning = fs.createReadStream(filePath, {start: 0, end: 255})
              beginning.on "data", (beginningChunk) ->
                fs.stat filePath, (err, stats) ->
                  end = fs.createReadStream(filePath, {start: stats.size - 256, end: stats.size})
                  end.on "data", (endChunk) ->
                    callback? sha1(beginningChunk + endChunk)
            fileSigGen rows[iteration].path, (fileSignature) ->
                  async.eachSeries probeData["streams"], ((stream, streamCallback) ->

                    # find video stream and make sure it has relevant data
                    if stream.codec_type is "video"
                      if typeof stream.width is "number" and stream.width > 0
                        stmt = db.prepare("UPDATE FILES SET status=?, filename=?,
                          filtered_filename=?, signature=?, width=?, height=?, size=?,
                          duration=? WHERE path=?")
                        stmt.run 'healthy', probeData.filename, filteredFileName, fileSignature, stream.width,
                          stream.height, probeData["format"].size, probeData["format"].duration, rows[iteration].path
                        stmt.finalize
                    streamCallback()
                  ), (err) ->
                    if rowsLength is iteration + 1
                      process.stdout.write(".done\n")
                      db.close ->
                        callback()
                    else
                      process.stdout.write('.')
                      probeFiles(iteration + 1)
      if rows.length > 0
        probeFiles(0)
      else
        callback()

  dbUpdate: (videoFiles, otherFiles, dirs, callback) ->
    console.log '==> '.cyan.bold + 'updating mediatidy database with current files and directories'

    # make sure db and tables exist
    db = new sqlite3.Database('data.db')
    createTable = (callback) ->
      db.run "CREATE TABLE IF NOT EXISTS DIRS (path TEXT UNIQUE, status TEXT)", ->
        db.run "CREATE TABLE IF NOT EXISTS FILES (path TEXT UNIQUE, status TEXT, filename TEXT,
          filtered_filename TEXT, signature TEXT, width INT, height INT, size INT, duration INT)", ->
          callback()

    addDirs = (callback) ->
      # prepare sql statement
      stmt = db.prepare("INSERT OR IGNORE INTO DIRS (path) VALUES (?)")

      # iterate through array of files to construct sql statement
      arrayLength = dirs.length
      i = 0
      while i < arrayLength

        stmt.run dirs[i]
        i++

      # insert data into db
      stmt.finalize
      callback()

    addVideoFiles = (callback) ->
      # prepare sql statement
      stmt = db.prepare("INSERT OR IGNORE INTO FILES (path, status) VALUES (?,?)")
      arrayLength = videoFiles.length
      i = 0
      while i < arrayLength
        stmt.run videoFiles[i], 'no_meta'
        i++

      # insert data into db
      stmt.finalize
      callback()

    addOtherFiles = (callback) ->
      # prepare sql statement
      stmt = db.prepare("INSERT OR IGNORE INTO FILES (path, status) VALUES (?,?)")
      arrayLength = otherFiles.length
      i = 0
      while i < arrayLength
        stmt.run otherFiles[i], 'other_file'
        i++

      # insert data into db
      stmt.finalize
      callback()

    async.series [
      (callback) ->
        createTable ->
          callback()
      (callback) ->
        console.log 'updating directories...'
        addDirs ->
          callback()
      (callback) ->
        console.log 'updating video files...'
        addVideoFiles ->
          callback()
      (callback) ->
        console.log 'updating other files...'
        addOtherFiles ->
          callback()
      (callback) ->
        db.close ->
          callback()
    # optional callback
    ], (err, results) ->
      console.log 'database updated'
      callback? true

  update: (callback) ->
    console.log '==> '.cyan.bold + 'search for current files and directories'

    # filter files array with the following subtitle file regex matches
    subtitles = [
      /\.idx$/i
      /\.srr$/i
      /\.sub$/i
    ]

    # filter files array with the following video file regex matches
    videoTypes = [
      /\.3gp$/i
      /\.asf$/i
      /\.avi$/i
      /\.divx$/i
      /\.flv$/i
      /\.m4v$/i
      /\.mkv$/i
      /\.mov$/i
      /\.mp4$/i
      /\.mpg$/i
      /\.mts$/i
      /\.m2ts$/i
      /\.ts$/i
      /\.wmv$/i
    ]

    path = @path
    dir.paths path, (err, paths) ->
      throw err if err

      # if video file regex push to video array
      paths.videoFiles = paths.files.filter((file) ->
        videoTypes.some (videoType) ->
          videoType.test file
      )
      console.log 'Found: ' + paths.videoFiles.length + ' video files'

      # if not a video file push to other file array
      paths.otherFiles = paths.files.filter((file) ->
        not videoTypes.some((videoType) ->
          videoType.test file
        )
      )
      console.log 'Found: ' + paths.otherFiles.length + " other files"

      console.log  'Found: ' + paths.dirs.length + ' directories'
      callback? paths.videoFiles, paths.otherFiles, paths.dirs

module.exports = Movies
