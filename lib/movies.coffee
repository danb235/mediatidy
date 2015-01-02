dir = require 'node-dir'
fs = require 'fs-extra'
probe = require 'node-ffprobe'
async = require 'async'
colors = require 'colors'
prompt = require 'prompt'
Database = require './db'

class Movies extends Database
  constructor: (@path) ->

  setup: (callback) ->
    @dbSetup ->
      callback()

  checkExists: (array, callback) ->
    missingFiles = []
    arrayLength = array.length

    fileExist = (iteration) =>
      fs.exists array[iteration].path, (exists) =>
        if exists is false
          console.log 'MISSING FILE:'.yellow, array[iteration].path
          missingFiles.push array[iteration]
        if arrayLength is iteration + 1
          console.log missingFiles.length + ' out of ' + arrayLength + ' files removed from database...'
          callback missingFiles
        else
          fileExist(iteration + 1)
    if arrayLength > 0
      fileExist(0)
    else
      console.log 'No files in database to check...'
      callback()

  promptUserBulkDelete: (array, message, callback) ->
    if array.length > 0
      arrayLength = array.length
      i = 0
      while i < arrayLength
        console.log "DELETE(?):".yellow, array[i].path
        i++

      # Start the prompt
      prompt.start()
      property =
        name: "yesno"
        message: message
        validator: /y[es]*|n[o]?/
        warning: "Must respond yes or no"
        # default: (if @program.yes is true then "yes" else "no")


      # get the simple yes or no property
      prompt.get property, (err, result) =>
        if result.yesno.match(/yes/i)

          fileDelete = (iteration) =>
            fs.unlink array[iteration].path, (err) =>
              throw err if err
              console.log "DELETED:".red, array[iteration].path

              if arrayLength is iteration + 1
                @dbBulkFileDelete array, ->
                  console.log 'files deleted and removed from database...'
                  callback()
              else
                fileDelete(iteration + 1)
          fileDelete(0)

        else
          console.log "No files deleted..."
          callback()
    else
      console.log "No files needed to be deleted!"
      callback()

  deleteCorrupt: (callback) ->
    console.log '==> '.cyan.bold + 'delete video files which appear to be corrupt'
    # get all files with tag 'CORRUPT'
    @dbBulkFileGetTag '\'CORRUPT\'', (files) =>
      promptMessage = "Delete all video files which are considered corrupt files?"
      @promptUserBulkDelete files, promptMessage, ->
        callback()

  deleteOthers: (callback) ->
    console.log '==> '.cyan.bold + 'delete files which are not video types'
    # get all files with tag 'OTHER'
    @dbBulkFileGetTag '\'OTHER\'', (files) =>
      promptMessage = "Delete all files that are not video types?"
      @promptUserBulkDelete files, promptMessage, ->
        callback()

  deleteSamples: (callback) ->
    console.log '==> '.cyan.bold + 'delete video files which appear to be sample files'
    # get all files with tag 'SAMPLE'
    @dbBulkFileGetTag '\'SAMPLE\'', (files) =>
      promptMessage = "Delete all video files which are considered sample files?"
      @promptUserBulkDelete files, promptMessage, ->
        callback()

  # deleteSmallFiles: (callback) ->
  #   console.log '==> '.cyan.bold + 'delete video files less than 100MB\'s in size'
  #   @dbBulkFileGetAll (files) =>
  #     promptMessage = "Delete all video files which are considered sample files?"
  #     @promptUserBulkDelete files, promptMessage, ->
  #       callback()

  exists: (callback) ->
    console.log '==> '.cyan.bold + 'removing files and directories from database that no longer exist'

    @dbBulkFileGetAll (files) =>
      @checkExists files, (missingFiles) =>
        if missingFiles > 0
          @dbBulkFileDelete missingFiles, ->
            console.log 'finished removing missing files from mediatidy database'
            callback()
        else
          callback()

  filesProbe: (array, callback) ->
    probedFiles = []
    arrayLength = array.length

    singleFileProbe = (iteration) =>
      probe array[iteration].path, (err, probeData) =>
        # throw err if err
        # console.log 'lolwut', iteration, array[iteration]
        # loop through streams to find video stream
        if typeof probeData is "undefined" or probeData["streams"].length is 0
          array[iteration].tag = 'CORRUPT'
          probedFiles.push array[iteration]
        else if probeData.filename.match(/sample/i)
          array[iteration].tag = 'SAMPLE'
          probedFiles.push array[iteration]
        else if probeData["streams"].length > 0

          # filter file name for future matching
          filteredFileName = probeData.filename.replace(/\.\w*$/, "")
          filteredFileName = filteredFileName.replace(/\s/g, "")
          filteredFileName = filteredFileName.replace(/\W/g, "")
          filteredFileName = filteredFileName.replace(/\d{4}.*$/g, "")
          filteredFileName = filteredFileName.toUpperCase()

          # set filename and filtered file name
          array[iteration].filename = probeData.filename
          array[iteration].filtered_filename = filteredFileName

          # get video files details
          async.eachSeries probeData["streams"], (stream, streamCallback) =>
            # find video stream and make sure it has relevant data
            if stream.codec_type is "video"
              if typeof stream.width is "number" and stream.width > 0
                array[iteration].tag = 'HEALTHY'
                array[iteration].width = stream.width
                array[iteration].height = stream.height
                array[iteration].size = probeData["format"].size
                array[iteration].duration = probeData["format"].duration

                probedFiles.push array[iteration]
            streamCallback()

        if arrayLength is iteration + 1
          process.stdout.write(".done\n")
          console.log probedFiles.length + ' out of ' + arrayLength + ' files probed...'
          callback probedFiles
        else
          process.stdout.write('.')
          singleFileProbe(iteration + 1)
    if arrayLength > 0
      process.stdout.write('.')
      singleFileProbe(0)
    else
      console.log 'No files in database to probe...'
      callback()

  fileMetaUpdate: (callback) ->
    console.log '==> '.cyan.bold + 'update database with probed video metadata'

    # get all files with tag 'VIDEO'
    @dbBulkFileGetTag '\'VIDEO\'', (files) =>
      console.log 'Found: ' + files.length + ' video files that need metadata update'
      @filesProbe files, (probedFiles) =>
        if probedFiles
          @dbBulkFileUpdate probedFiles, ->
            console.log 'finished adding probe data to mediatidy database'
            callback()
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
    if array.length > 0
      arrayLength = array.length
      i = 0
      while i < arrayLength
        arrayObjects.push
          path: array[i]
          tag: tag
        i++
        if i is arrayLength
          callback arrayObjects
    else
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
