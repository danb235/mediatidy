prompt = require 'prompt'
Database = require './db'

class Config extends Database

  pathPrompt: (callback) ->
    console.log '==> '.cyan.bold + 'delete video files which appear to be corrupt'

    currentPaths = []
    newPaths = []

    # prompt.override = program.args[0]
    prompt.message = "mediatidy".yellow
    prompt.delimiter = ": ".green
    prompt.properties =
      path:
        description: 'media path'
        message: 'enter path to media files'
        # default: program.path
        required: true

    # saveConfig = (result) ->
    #   Config.set 'path', result?.path or program.path
    #
    #   Config.save (error) ->
    #     console.log error.message if error?
    #     console.log "saved mediatidy configuration to db"

    # unless program.yes?
    prompt.start()
    prompt.get ['path'], (error, result) ->
      console.log 'yes', result
      # saveConfig result unless error?


  promptUserPathAdd: (callback) ->
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

  setup: (callback) ->
    @dbSetup ->
      callback()

module.exports = Config
