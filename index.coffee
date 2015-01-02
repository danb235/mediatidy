movies = require "./lib/movies"
config = require "./lib/config"
database = require "./lib/db"

module.exports =
	Config: config
	Database: database
	Movies: movies
