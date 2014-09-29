dir = require('node-dir')
sqlite3 = require("sqlite3").verbose()
sha1 = require("node-sha1")
fs = require('fs-extra')
probe = require('node-ffprobe')
async = require('async')
colors = require 'colors'

class Movies
  constructor: (@path) ->

  dbRead: (callback) ->
    console.log 'retrieving files from database...'

    # read all rows from the files table
    db = new sqlite3.Database('data.db')
    db.all "SELECT rowid AS id, filename, status FROM FILES", (err, rows) ->
      rows.forEach (row) ->
        console.log row.id, row.status, row.filename
      db.close ->
        console.log 'Total files: ' + rows.length + '...'
        callback()

  dbExists: (callback) ->
    console.log 'look for files that no longer exist...'
    db = new sqlite3.Database('data.db')
    db.all "SELECT rowid AS id, path, status FROM FILES", (err, rows) ->
      i = 0
      async.eachSeries rows, ((file, rowCallback) ->
        console.log 'Check that file exists:', file.rowid, file.path, file.status
        fs.exists file.path, (exists) ->
          if exists is false
            console.log 'Removing missing file from db:', file.path
            stmt = db.prepare("DELETE FROM FILES WHERE path=?")
            stmt.run file.path
            stmt.finalize
            console.log file.path, exists
            rowCallback()
          else
            console.log 'Exists:', file.path
            rowCallback()
      ), (err) ->
        console.log 'exists lolwut...'
        db.close ->
          console.log 'db closed...'
          callback()

  dbMetaUpdate: (callback) ->
    console.log 'updating metadata for video files in database...'

    db = new sqlite3.Database('data.db')
    db.all "SELECT rowid AS id, path, status FROM FILES WHERE status=\'no_meta\'", (err, rows) ->
      rowsLength = rows.length
      probeFiles = (iteration) ->
        console.log rowsLength, iteration, 'PROBING:', '>' + rows[iteration].path + '<'
        probe rows[iteration].path, (err, probeData) ->
          # loop through streams to find video stream
          if typeof probeData is "undefined"
            console.log 'Cannot extract metadata from ' + rows[iteration].path + '...'
            stmt = db.prepare("UPDATE FILES SET status=? WHERE path=?")
            stmt.run 'corrupt', rows[iteration].path
            stmt.finalize
            probeFiles(iteration + 1)
          else if probeData["streams"].length > 0
            async.eachSeries probeData["streams"], ((stream, streamCallback) ->

              # find video stream and make sure it has relevant data
              if stream.codec_type is "video"
                if typeof stream.width is "number" and stream.width > 0
                  console.log 'Updating:', rows[iteration].path
                  stmt = db.prepare("UPDATE FILES SET status=?, filename=?,
                    resolution=?, size=?, duration=? WHERE path=?")
                  stmt.run 'healthy', probeData.filename, stream.width * stream.height,
                    probeData["format"].size, probeData["format"].duration, rows[iteration].path
                  stmt.finalize
              streamCallback()
            ), (err) ->
              if rowsLength is iteration + 1
                db.close ->
                  callback()
              else
                probeFiles(iteration + 1)
      if rows.length > 0
        probeFiles(0)
      else
        callback()


      # i = 0
      # async.each rows, ((file, rowCallback) ->
      #   # console.log i, file.id, file.path
      #   # i++
      #   # rowCallback()
      #   if file.status is 'no_meta'
      #     console.log i, 'PROBING: '.red + file.path
      #     i++
      #     probe file.path, (err, probeData) ->
      #       # loop through streams to find video stream
      #       if typeof probeData is "undefined"
      #         console.log 'Cannot extract metadata from ' + file.path + '...'
      #         stmt = db.prepare("UPDATE FILES SET status=? WHERE path=?")
      #         stmt.run 'corrupt', file.path
      #         stmt.finalize
      #       else if probeData["streams"].length > 0
      #         async.eachSeries probeData["streams"], (stream, streamCallback) ->

      #           # find video stream and make sure it has relevant data
      #           if stream.codec_type is "video"
      #             if typeof stream.width is "number" and stream.width > 0
      #               console.log 'Updating:', file.path
      #               stmt = db.prepare("UPDATE FILES SET status=?, filename=?,
      #                 resolution=?, size=?, duration=? WHERE path=?")
      #               stmt.run 'healthy', probeData.filename, stream.width * stream.height,
      #                 probeData["format"].size, probeData["format"].duration, file.path
      #               stmt.finalize
      #           streamCallback()
      #     rowCallback()
      #   else
      #     console.log i, 'File already probed or not video:', file.path
      #     i++
      #     rowCallback()
      # ), (err) ->
        # console.log 'lolwut...'
        # db.close ->
        #   console.log 'db closed...'
        #   callback()

  dbUpdate: (videoFiles, otherFiles, dirs, callback) ->
    console.log 'updating database with latest files and directories...'

    # make sure db and tables exist
    db = new sqlite3.Database('data.db')
    createTable = (callback) ->
      db.run "CREATE TABLE IF NOT EXISTS DIRS (path TEXT UNIQUE)", ->
        db.run "CREATE TABLE IF NOT EXISTS FILES (path TEXT UNIQUE, status TEXT, filename TEXT, resolution INT, size INT, duration INT)", ->
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

    # create db and tables; add any files not already in db
    createTable ->
      addDirs ->
        console.log 'dirs added to database...'
        addOtherFiles ->
          console.log 'other files added to database...'
          addVideoFiles ->
            console.log 'video files added to database...'
            db.close ->
              console.log 'database update complete...'
              callback? true

  update: (callback) ->
    console.log 'looking for files and directories at', @path, '...'

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
      console.log paths.videoFiles.length + " video files found..."

      # if not a video file push to other file array
      paths.otherFiles = paths.files.filter((file) ->
        not videoTypes.some((videoType) ->
          videoType.test file
        )
      )
      console.log paths.otherFiles.length + " other files found..."

      console.log  paths.dirs.length + ' directories found...'
      callback? paths.videoFiles, paths.otherFiles, paths.dirs

module.exports = Movies
