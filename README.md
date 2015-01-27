# mediatidy

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

Coming soon:
* Delete files under a specified size.
* Tidy up your media directories by keyword.
* Media files view.
* Ability to rename files.

<!-- ## Current Assumptions

* Your movie files follow a similar naming pattern (such as `Young Frankenstein (1974).mkv`) -->

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
