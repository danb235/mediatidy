dir = require 'node-dir'
fs = require 'fs-extra'
probe = require 'node-ffprobe'
async = require 'async'
colors = require 'colors'
prompt = require 'prompt'
Database = require './db'
_ = require 'lodash'
prettyBytes = require 'pretty-bytes'
ProgressBar = require 'progress'

class Media extends Database

  addFiles: (callback) ->
    console.log '==> '.cyan.bold + 'search for and add files to database...'

    # video file extensions
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

    # get base paths from db
    @dbBulkPathGet '\'MEDIA\'', (array) =>
      if array.length is 0
        console.log "No paths have been added to mediatidy. Add paths to your media files with",
          "\"mediatidy config paths-update\"".red
      else
        # get files asynchronously for each 'MEDIA' path
        async.eachSeries array, ((basePath, seriesCallback) =>

          fs.exists basePath.path, (exists) =>
            if exists
              # get files for given path
              dir.paths basePath.path, (err, paths) =>
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
                      console.log basePath.path + ':', result, 'video file types...'
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
                      console.log basePath.path + ':', result, 'other file types...'
                      callback()
                ], (err, result) ->
                  throw err if err
                  seriesCallback()
            else
              console.log basePath.path, 'could not be found. Consider updating media dirs...'
              seriesCallback()
        ), (err) ->
          if err
            console.log "Something broke when looking for files...", err
          else
            callback()

  convertArray: (array, tag, callback) ->
    # convert each result from array to array of objects
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

  checkExists: (array, callback) ->
    # check that each file path in database exists in the file system
    missingFiles = []
    arrayLength = array.length

    fileExist = (iteration) =>
      fs.exists array[iteration].path, (exists) =>
        if exists is false
          console.log 'MISSING FILE:'.yellow, array[iteration].path
          missingFiles.push array[iteration]
        if arrayLength is iteration + 1 and missingFiles.length > 0
          console.log missingFiles.length + ' out of ' + arrayLength + ' files removed from database...'
          callback missingFiles
        else if arrayLength is iteration + 1 and missingFiles.length is 0
          console.log 'No files needed to be removed from database...'
          callback missingFiles
        else
          fileExist(iteration + 1)
    if arrayLength > 0
      fileExist(0)
    else
      console.log 'No files in database to check...'
      callback()

  deleteCorrupt: (callback) ->
    console.log '==> '.cyan.bold + 'delete video files which appear to be corrupt'
    # get all files with tag 'CORRUPT'
    @dbBulkFileGetTag '\'CORRUPT\'', (files) =>
      # prompt user to delete corrupt files
      promptMessage = "Delete all video files which are considered corrupt files?"
      @promptUserBulkDelete files, promptMessage, ->
        callback()

  findDupes: (array, callback) ->
    arrayLength = array.length

    if arrayLength > 0

      async.waterfall [
        (callback) ->
          objectStore = {}
          _.forEach array, (file, iteration) =>
            objectStore[file.filtered_filename] = [] unless objectStore.hasOwnProperty(file.filtered_filename)
            objectStore[file.filtered_filename].push file

            if iteration is arrayLength - 1
              callback null, objectStore
        (objectStore, callback) ->
          possibleDupes = []
          objectLength = _.size(objectStore)
          count = 1
          _.forEach objectStore, (fileCollection) =>
            if fileCollection.length > 1
              possibleDupes.push fileCollection
            if count is objectLength - 1
              callback null, possibleDupes
            count++
      ], (err, result) ->
        callback result

    else
      console.log 'No files in database to check...'
      callback()

  promptUserDupeDelete: (array, callback) ->

    _.forEach array, (file, j) =>
      if j is 0
        console.log "KEEP:".green, file.path, "width:", file.width, "height:", file.height, "size:", prettyBytes(file.size)
      else
        console.log "DELETE(?):".yellow, file.path, "width:", file.width, "height:", file.height, "size:", prettyBytes(file.size)

    prompt.message = "mediatidy".yellow
    prompt.delimiter = ": ".green
    prompt.properties =
      yesno:
        default: 'no'
        message: 'Keep highest quality file; delete lower quality duplicates?'
        required: true
        warning: "Must respond yes or no"
        validator: /y[es]*|n[o]?/

    # Start the prompt
    prompt.start()

    # get the simple yes or no property
    prompt.get ['yesno'], (err, result) =>
      if result.yesno.match(/yes/i)

        _.forEach array.slice(1), (file, j) =>
          fs.unlink file.path, (err) =>
            throw err if err
            console.log "DELETED:".red, file.path

          if array.slice(1).length is j + 1
            @dbBulkFileDelete array.slice(1), ->
              console.log 'files deleted and removed from database...'
              callback()
      else
        console.log "No files deleted..."
        callback()

  dupeSort: (array, callback) ->
    sortedDupes = []
    _.forEach array, (dupes, i) =>

      # sort files by size
      dupes.sort (a, b) ->
        (a.size) - (b.size)
      dupes.reverse()
      sortedDupes.push dupes

      if array.length - 1 is i
        callback sortedDupes

  deleteDupes: (callback) ->
    console.log '==> '.cyan.bold + 'delete duplicate lower quality video files'
    # get all files with tag 'HEALTHY'
    @dbBulkFileGetTag '\'HEALTHY\'', (files) =>
      @findDupes files, (dupes) =>
        @dupeSort dupes, (sortedDupes) =>
          deleteDupes = (iteration) =>
            @promptUserDupeDelete sortedDupes[iteration], ->
              if sortedDupes.length is iteration + 1
                callback()
              else
                deleteDupes(iteration + 1)
          deleteDupes(0)

  deleteOthers: (callback) ->
    console.log '==> '.cyan.bold + 'delete files which are not video types'
    # get all files with tag 'OTHER'
    @dbBulkFileGetTag '\'OTHER\'', (files) =>
      # prompt user to delete other files
      promptMessage = "Delete all files that are not video types?"
      @promptUserBulkDelete files, promptMessage, ->
        callback()

  deleteSamples: (callback) ->
    console.log '==> '.cyan.bold + 'delete video files which appear to be sample files'
    # get all files with tag 'SAMPLE'
    @dbBulkFileGetTag '\'SAMPLE\'', (files) =>
      # prompt user to delete sample files
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

    # get all files
    @dbBulkFileGetAll (files) =>
      # check if files exist for a given path
      @checkExists files, (missingFiles) =>
        if missingFiles.length > 0
          # remove missing files from database
          @dbBulkFileDelete missingFiles, ->
            console.log 'finished removing missing files from mediatidy database'
            callback()
        else
          callback()

  fileMetaUpdate: (callback) ->
    console.log '==> '.cyan.bold + 'update database with probed video metadata'

    # get all files with tag 'VIDEO'
    @dbBulkFileGetTag '\'VIDEO\'', (files) =>
      if files.length > 0
        console.log 'Found: ' + files.length + ' video files that need metadata update'
      # probe each files that does not have meta info
      @filesProbe files, (probedFiles) =>
        if probedFiles
          # update database with meta info
          @dbBulkFileUpdate probedFiles, ->
            console.log 'finished adding probe data to mediatidy database'
            callback()
        else
          callback()

  filesProbe: (array, callback) ->
    # gather information about media files
    probedFiles = []
    arrayLength = array.length
    bar = new ProgressBar("Probing files: Total: :total Current: :current Completion Time: :etas",
      total: arrayLength
    )

    singleFileProbe = (iteration) =>
      probe array[iteration].path, (err, probeData) =>

        # tag corrupt files
        if typeof probeData is "undefined" or probeData["streams"].length is 0
          array[iteration].tag = 'CORRUPT'
          probedFiles.push array[iteration]

        # tag sample files
        else if probeData.filename.match(/sample/i)
          array[iteration].tag = 'SAMPLE'
          probedFiles.push array[iteration]

        # otherwise continue
        else if probeData["streams"].length > 0

          # remove file extension
          filteredFileName = probeData.filename.replace(/\.\w*$/, "")

          # remove white space
          filteredFileName = filteredFileName.replace(/\s/g, "")

          # remove any non word character
          filteredFileName = filteredFileName.replace(/\W/g, "")

          # filteredFileName = filteredFileName.replace(/\d{4}.*$/g, "")
          # make all uppercase
          filteredFileName = filteredFileName.toUpperCase()

          # set filename and filtered file name
          array[iteration].filename = probeData.filename
          array[iteration].filtered_filename = filteredFileName

          # loop through video streams to find needed stream info
          async.eachSeries probeData["streams"], (stream, streamCallback) =>
            if stream.codec_type is "video"
              if typeof stream.width is "number" and stream.width > 0
                # add relevent date to object
                array[iteration].tag = 'HEALTHY'
                array[iteration].width = stream.width
                array[iteration].height = stream.height
                array[iteration].size = probeData["format"].size
                array[iteration].duration = probeData["format"].duration

                # push object to array
                probedFiles.push array[iteration]
                bar.tick()
            streamCallback()

        if arrayLength is iteration + 1
          console.log probedFiles.length + ' out of ' + arrayLength + ' files probed...'
          callback probedFiles
        else
          singleFileProbe(iteration + 1)
    if arrayLength > 0
      singleFileProbe(0)
    else
      console.log 'No files in database needed to be probed...'
      callback()

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

  promptUserBulkDelete: (array, message, callback) ->
    if array.length > 0
      # display media files up for deletion
      arrayLength = array.length
      i = 0
      while i < arrayLength
        console.log "DELETE(?):".yellow, array[i].path
        i++

      prompt.message = "mediatidy".yellow
      prompt.delimiter = ": ".green
      prompt.properties =
        yesno:
          default: 'no'
          message: message
          required: true
          warning: "Must respond yes or no"
          validator: /y[es]*|n[o]?/

      # Start the prompt
      prompt.start()

      # get the simple yes or no property
      prompt.get ['yesno'], (err, result) =>
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
      console.log "No files needed to be deleted..."
      callback()

  setup: (callback) ->
    # setup the database
    @dbSetup ->
      callback()

module.exports = Media
