Sequelize = require 'sequelize'

class Database
  dbSetup: (callback) ->
    sequelize = new Sequelize("database", "username", "password",
      dialect: "sqlite"
      storage: "database.sqlite"
      logging: false
    )
    # Create file table if it does not exist
    @File = sequelize.define("Files",
      path: {type: Sequelize.STRING, unique: true}
      status: Sequelize.STRING
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

  dbBulkFileUpdate: (array, callback) ->
    console.log array.length
    @File.bulkCreate(array).done (err, result) ->
      # console.log err, result
      callback err, result

module.exports = Database
