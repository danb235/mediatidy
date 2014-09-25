dir = require('node-dir')
sqlite3 = require("sqlite3").verbose()
sha1 = require("node-sha1")
fs = require('fs-extra')
probe = require('node-ffprobe')
async = require('async')

class Movies
  constructor: (@path) ->

  dbRead: (callback) ->
    console.log 'retrieving files from database...'

    # read all rows from the files table
    files = []
    db = new sqlite3.Database('data.db')
    db.all "SELECT rowid AS id, filename, status FROM FILES", (err, rows) ->
      rows.forEach (row) ->
        console.log row.id, row.status, row.filename
      db.close ->
        callback? files

  dbMetaUpdate: (callback) ->
    console.log 'updating metadata for video files in database...'

    db = new sqlite3.Database('data.db')
    db.all "SELECT rowid AS id, path, status FROM FILES", (err, rows) ->
      i = 0
      async.eachSeries rows, (file, rowCallback) ->
        if file.status is 'no_meta'
          console.log('PROBING: '.red + file.path);
          probe file.path, (err, probeData) ->
            # loop through streams to find video stream
            if typeof probeData is "undefined"
              console.log 'Cannot extract metadata from ' + file.path + '...'
              stmt = db.prepare("UPDATE FILES SET status=? WHERE path=?")
              stmt.run 'corrupt', file.path
              stmt.finalize
            else if probeData["streams"].length > 0
              async.eachSeries probeData["streams"], (stream, streamCallback) ->

                # find video stream and make sure it has relevant data
                if stream.codec_type is "video"
                  if typeof stream.width is "number" and stream.width > 0
                    console.log 'Updating:', file.path
                    stmt = db.prepare("UPDATE FILES SET status=?, filename=?,
                      resolution=?, size=?, duration=? WHERE path=?")
                    stmt.run 'healthy', probeData.filename, stream.width * stream.height,
                      probeData["format"].size, probeData["format"].duration, file.path
                    stmt.finalize
                streamCallback()
            rowCallback()
        else
          console.log 'File already probed or not video:', file.path
          rowCallback()
        i++
        if i is rows.length
          console.log 'lolwut...'
          db.close ->
            console.log 'db closed...'
            callback()

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

    addFiles = (callback) ->
        # prepare sql statement
        stmt = db.prepare("INSERT OR IGNORE INTO FILES (path, status) VALUES (?,?)")
        async.eachSeries videoFiles, (file, callback) ->
          stmt.run file,'no_meta'
          callback()
        async.eachSeries otherFiles, (file, callback) ->
          stmt.run file,'other_file'
          callback()

        # insert data into db
        stmt.finalize
        callback()

    # create db and tables; add any files not already in db
    createTable ->
      addDirs ->
        console.log 'dirs added to database...'
        addFiles ->
          console.log 'files added to database...'
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
