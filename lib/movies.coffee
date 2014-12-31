dir = require('node-dir')
sqlite3 = require("sqlite3").verbose()
fs = require('fs-extra')
probe = require('node-ffprobe')
async = require('async')
colors = require 'colors'
Database = require './db'

class Movies extends Database
  constructor: (@path) ->

  setup: (callback) ->
    console.log 'setting up the bomb'
    @dbSetup ->
      'we have signal'
      callback()

  dbRead: (callback) ->
    console.log '==> '.cyan.bold + 'read from database'
    console.log @foo

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

  addFiles: (callback) ->
    console.log '==> '.cyan.bold + 'search for and add files to database...'

    movieFileExtensions = [
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
    dir.paths path, (err, paths) =>
      throw err if err

      # add files to db asynchronously
      async.waterfall [
        # add video files to db
        (callback) =>
          # filter files with video file extension
          @filterFileTypes paths.files, movieFileExtensions, (movieFiles) ->
            callback null, movieFiles
        (movieFiles, callback) =>
          # convert array of files to array of objects
          @convertArray movieFiles, 'VIDEO', (fileObjects) ->
            callback null, fileObjects
        (fileObjects, callback) =>
          # add files to database
          @dbBulkFileAdd fileObjects, (result) ->
            # throw err if err
            console.log 'video file types found and added to db:', result
            callback()

        # add all other files to db
        (callback) =>
          # filter files without video extensions
          @filterFileTypesOpposite paths.files, movieFileExtensions, (otherFiles) ->
            callback null, otherFiles
        (otherFiles, callback) =>
          # convert array of files to array of objects
          @convertArray otherFiles, 'OTHER', (fileObjects) ->
            callback null, fileObjects
        (fileObjects, callback) =>
          # add files to database
          @dbBulkFileAdd fileObjects, (result) ->
            # throw err if err
            console.log 'other file types found and added to db:', result
            callback()
      ], (err, result) ->
        throw err if err
        callback()

  convertArray: (array, tag, callback) ->
    # convert each result to object
    arrayObjects = []
    arrayLength = array.length
    i = 0
    while i < arrayLength
      arrayObjects.push
        path: array[i]
        tag: tag
      i++
      if i is arrayLength
        callback arrayObjects

  filterFileTypes: (filesArray, filterArray, callback) ->
    # filter files array with the following video file regex matches
    filteredFiles = filesArray.filter((file) ->
      filterArray.some (videoType) ->
        videoType.test file
    )
    callback filteredFiles

  filterFileTypesOpposite: (filesArray, filterArray, callback) ->
    # filter files array with the opposite file regex matches
    filteredFiles = filesArray.filter((file) ->
      not filterArray.some (videoType) ->
        videoType.test file
    )
    callback filteredFiles

module.exports = Movies
