Sequelize = require 'sequelize'
async = require 'async'

class Database
  dbSetup: (callback) ->
    sequelize = new Sequelize("database", "username", "password",
      dialect: "sqlite"
      storage: "database.sqlite"
      logging: false
    )
    # Create file table if it does not exist
    @File = sequelize.define("FILES",
      path: {type: Sequelize.STRING, unique: true}
      tag: Sequelize.STRING
      filename: Sequelize.STRING
      filtered_filename: Sequelize.STRING
      width: Sequelize.INTEGER
      height: Sequelize.INTEGER
      size: Sequelize.INTEGER
      duration: Sequelize.INTEGER
    )
    sequelize.sync(force: false).complete (err) ->
      unless not err
        console.log "An error occurred while creating the table:", err
      else
        console.log "Database table updatd..."
        callback()

  dbBulkFileAdd: (array, callback) ->
    #
    # !!currently breaks at 12,500 files!! :(
    #
    arrayLength = array.length
    chunk = 250
    offset = 0
    recursiveBulkAdd = =>
      arrayChunk = array.splice(offset, Math.min(chunk, arrayLength - offset))
      @File.bulkCreate(arrayChunk, {ignoreDuplicates: true}).done (err, result) ->
        # console.log err, result.length
        # console.log 'array length:', arrayLength, 'array chunk length:', arrayChunk.length,
        #   'offset:', offset, 'chunk:', chunk, 'length - offset:', arrayLength - offset
        offset = offset + chunk
        if offset < arrayLength
          recursiveBulkAdd()
        else
          callback err, result
    recursiveBulkAdd()




    # console.log err, result.length
    # console.log 'array length:', arrayLength, 'array chunk length:', arrayChunk.length,
    #   'offset:', offset, 'chunk:', chunk, 'length - offset:', arrayLength - offset

    # if arrayLength < chunkSize
    #   @File.bulkCreate(array, {ignoreDuplicates: true}).done (err, result) ->
    #     console.log err, result
    #     callback err, result
    # else
    #   recursiveBulkAdd (iteration) ->
    #
    #   recursiveBulkAdd(chunkSize)


module.exports = Database
