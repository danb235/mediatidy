#!/usr/bin/env coffee

pkg = require '../package.json'
program = require 'commander'
Config = require '../lib/config'
Media = require '../lib/media'
Dirs = require '../lib/dirs'
colors = require 'colors'
async = require 'async'

program.version(pkg.version)

program.command('clean')
  .description('Let\'s tidy up those media files and directories!')
  .action () ->
    config = new Config
    dirs = new Dirs
    media = new Media

    # Perform action in series with async
    async.series [

      # Ensure db is setup
      (callback) ->
        config.setup ->
          callback()
      # Clean files
      (callback) ->
        media.suite ->
          callback()
      # Clean dirs
      (callback) ->
        dirs.suite ->
          callback()
    ], (err, results) ->
      throw err if err
      console.log 'Your media is looking mighty tidy!'

program.command('clean-dirs')
  .description('Let\'s tidy up those media directories!')
  .action () ->
    config = new Config
    dirs = new Dirs

    async.series [
      (callback) ->
        config.setup ->
          callback()
      (callback) ->
        dirs.suite ->
          callback()
    ], (err, results) ->
      throw err if err
      console.log 'Your media directories are looking mighty tidy!'

program.command('clean-files')
  .description('Let\'s tidy up those media files!')
  .action () ->
    config = new Config
    media = new Media

    async.series [
      (callback) ->
        config.setup ->
          callback()
      (callback) ->
        media.suite ->
          callback()
    ], (err, results) ->
      throw err if err
      console.log 'Your media files are looking mighty tidy!'

program
  .command('add-paths')
  .description('Add paths to media files for mediatidy to tidy up!')
  .action () ->
    config = new Config

    async.series [
      (callback) ->
        config.setup ->
          callback()
      (callback) ->
        config.pathPrompt ->
          callback()
    ], (err, results) ->
      throw err if err
      console.log 'Media path add complete.'

program
  .command('remove-paths')
  .description('Remove all media paths from mediatidy')
  .action () ->
    config = new Config

    async.series [
      (callback) ->
        config.setup ->
          callback()
      (callback) ->
        config.pathsDelete ->
          callback()
    ], (err, results) ->
      throw err if err
      console.log 'All media paths have been removed from mediatidy.'

program
  .command('remove-files')
  .description('Remove all media file data from mediatidy database')
  .action () ->
    config = new Config

    async.series [
      (callback) ->
        config.setup ->
          callback()
      (callback) ->
        config.filesDelete ->
          callback()
    ], (err, results) ->
      throw err if err
      console.log 'All file data has been removed from mediatidy database.'

program.parse(process.argv)

program.help() if program.args.length is 0
