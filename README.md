# mediatidy

[![Greenkeeper badge](https://badges.greenkeeper.io/tkdan235/mediatidy.svg)](https://greenkeeper.io/)

For anyone with a large media collection (movies and tv shows) who craves file organization,
**mediatidy** is a project that helps you keep your content... tidy.

This project is early in dev and a WIP. Please file issues!

## About

Point **mediatidy** at your movie or TV show directory and it will do the following (any file deletion requires your approval):
* Delete all non-video type files.
* Delete all corrupt/incomplete video files.
* Delete all sample files.
* Process files to find dupes; keep the highest quality of the dupes and delete the rest.
* Delete directories that are empty
* Delete directories that match keywords saved by user

Coming soon:
* Delete files under a specified size.
* Media files view.
* Ability to rename files.

## File Naming Assumptions

For dupe detection to work best your files should be properly named.  **mediatidy** works best with the following conventions:

Movies should have title followed by year:
* `Movie Title (1974).mkv`
* `Movie Title - 1974.mkv`
* `Movie Title 1974.mkv`

TV shows should be have show name, followed by formatted season/episode, then episode name:
* `Show Name - S02E03 - Ep Name.mkv`
* `Show Name - S02E03e01 - Ep Name.mkv`
* `Show Name - 02x03 - Ep Name.mkv`
* `Show Name - 2014.03.07 - Ep Name.mkv`

Without proper file naming conventions duplicate matching can be unreliable.  You do want to be tidy right?

## Setup
### Dependencies

[NodeJS](http://nodejs.org/) and [ffmpeg](https://www.ffmpeg.org/) are required to run mediatidy. Find the installers and install the latest versions; if using Mac OSX consider installing [homebrew](http://brew.sh/) and easily install what you need with the following:  


```
$ brew install node
$ brew install ffmpeg
```

### Install

Be sure all [dependencies](#Dependencies) are install before installing **mediatidy**.

```
$ sudo npm install -g mediatidy
```

### Uninstall

```
$ sudo npm uninstall -g mediatidy
$ rm -rf ~/.mediatidy
```

## Usage
See **mediatidy** help for a full list of commands.

```
$ mediatidy --help
```

### Basics

Add media folder to **mediatidy** you would like to process with:

```
$ mediatidy add-paths
```

Let's tidy up those media files!

```
$ mediatidy clean
```
