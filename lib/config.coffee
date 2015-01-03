prompt = require 'prompt'
Database = require './db'

class Config extends Database

  pathPromptYesNo: (callback) ->
    @dbBulkPathGet '\'MEDIA\'', (array) =>

      arrayLength = array.length
      i = 0
      while i < arrayLength
        console.log "CURRENT PATH:".yellow, array[i].path
        i++

      if arrayLength is 0
        @pathPromptAdd =>
          @pathPromptYesNo ->
            callback()
      else
        prompt.message = "mediatidy".yellow
        prompt.delimiter = ": ".green
        prompt.properties =
          yesno:
            default: 'no'
            message: 'Add another media path to mediatidy?'
            required: true
            warning: "Must respond yes or no"
            validator: /y[es]*|n[o]?/

        # Start the prompt
        prompt.start()

        # get the simple yes or no property
        prompt.get ['yesno'], (err, result) =>
          if result.yesno.match(/yes/i)
            @pathPromptAdd =>
              @pathPromptYesNo ->
                callback()
          else
            console.log "Finished adding paths..."
            callback()

  pathPromptAdd: (callback) ->
    prompt.message = "mediatidy".yellow
    prompt.delimiter = ": ".green
    prompt.properties =
      path:
        description: 'enter full path to media files (movies or tv shows)'
        message: 'enter path to media files'
        required: true

    prompt.start()
    prompt.get ['path'], (error, result) =>
      # remove trailing forward slash
      result.path = result.path.replace(/\/$/, "")
      @dbPathAdd result.path, 'MEDIA', ->
        callback()

  pathPrompt: (callback) ->
    console.log '==> '.cyan.bold + 'update paths to media files for mediatidy to tidy up!'
    @pathPromptYesNo =>
      callback()

  pathDropPromptYesNo: (callback) ->
    @dbBulkPathGet '\'MEDIA\'', (array) =>

      arrayLength = array.length
      i = 0
      while i < arrayLength
        console.log "CURRENT PATH:".yellow, array[i].path
        i++

      prompt.message = "mediatidy".yellow
      prompt.delimiter = ": ".green
      prompt.properties =
        yesno:
          message: 'Delete all media paths from mediatidy?'
          required: true
          warning: "Must respond yes or no"
          validator: /y[es]*|n[o]?/

      # Start the prompt
      prompt.start()

      # get the simple yes or no property
      prompt.get ['yesno'], (err, result) =>
        if result.yesno.match(/yes/i)
          @pathPromptAdd =>
            @pathPromptYesNo ->
              callback()
        else
          console.log "Finished adding paths..."
          callback()

  pathsDelete: (callback) ->
    console.log '==> '.cyan.bold + 'remove all media paths from mediatidy'
    @dbBulkPathGet '\'MEDIA\'', (array) =>

      arrayLength = array.length
      i = 0
      while i < arrayLength
        console.log "CURRENT PATH:".yellow, array[i].path
        i++

      prompt.message = "mediatidy".yellow
      prompt.delimiter = ": ".green
      prompt.properties =
        yesno:
          message: 'Delete all paths from mediatidy?'
          required: true
          warning: "Must respond yes or no"
          validator: /y[es]*|n[o]?/

      # Start the prompt
      prompt.start()

      # get the simple yes or no property
      prompt.get ['yesno'], (err, result) =>
        if result.yesno.match(/yes/i)
          @dbPathDelete '\'MEDIA\'', =>
            console.log "All media paths removed..."
            callback()
        else
          console.log "No media paths were removed..."
          callback()

  setup: (callback) ->
    @dbSetup ->
      callback()

module.exports = Config
