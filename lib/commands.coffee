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
  .description('Let\'s tidy up those media files!')
  .action () ->
    media = new Media
    dirs = new Dirs

    # Perform action in series with async
    async.series [

      # Clean files
      (callback) ->
        media.addFiles ->
          callback()
      (callback) ->
        media.fileExists ->
          callback()
      (callback) ->
        media.fileMetaUpdate ->
          callback()
      (callback) ->
        media.deleteCorrupt ->
          callback()
      (callback) ->
        media.deleteSamples ->
          callback()
      (callback) ->
        media.deleteOthers ->
          callback()
      (callback) ->
        media.deleteDupes ->
          callback()

      # Clean dirs
      (callback) ->
        dirs.addDirs ->
          callback()
      (callback) ->
        dirs.dirExists ->
          callback()
      (callback) ->
        dirs.deleteEmptyDirs ->
          callback()
    ], (err, results) ->
      throw err if err
      console.log 'Your media is looking mighty tidy!'

program.command('clean-dirs')
  .description('Let\'s tidy up those media directories!')
  .action () ->
    dirs = new Dirs

    async.series [
      (callback) ->
        dirs.addDirs ->
          callback()
      (callback) ->
        dirs.dirExists ->
          callback()
      (callback) ->
        dirs.deleteEmptyDirs ->
          callback()
    ], (err, results) ->
      throw err if err
      console.log 'Your media directories are looking mighty tidy!'

program
  .command('add-paths')
  .description('Add paths to media files for mediatidy to tidy up!')
  .action () ->
    config = new Config

    async.series [
      (seriesCallback) ->
        config.setup ->
          seriesCallback()
      (seriesCallback) ->
        config.pathPrompt ->
          seriesCallback()
    ], (err, results) ->
      throw err if err
      console.log 'Media path add complete.'

program
  .command('remove-paths')
  .description('Remove all media paths from mediatidy')
  .action () ->
    config = new Config

    async.series [
      (seriesCallback) ->
        config.pathsDelete ->
          seriesCallback()
    ], (err, results) ->
      throw err if err
      console.log 'All media paths have been removed from mediatidy.'

program
  .command('remove-files')
  .description('Remove all media file data from mediatidy database')
  .action () ->
    config = new Config

    async.series [
      (seriesCallback) ->
        config.filesDelete ->
          seriesCallback()
    ], (err, results) ->
      throw err if err
      console.log 'All file data has been removed from mediatidy database.'

program.parse(process.argv)

program.help() if program.args.length is 0
