# mediatidy

For anyone with a large media collection (movies and tv shows) who craves file organization,
**mediatidy** is a nodejs project that helps you keep your content... tidy.

This project is early in dev and a WIP. Please file issues!

## About

Point **mediatidy** at your movie or TV show directory and it will do the following (any file deletion requires your approval):
* Delete all non-video type files
* Delete all corrupt/incomplete video files
* Delete all sample files
* Process files to find dupes; keep the highest quality of the dupes and delete the rest

Coming soon:
* Delete files under a specified size
* Delete empty directories

<!-- ## Current Assumptions

* Your movie files follow a similar naming pattern (such as `Young Frankenstein (1974).mkv`) -->

## Environment Setup (OSX)
### Dependencies
If starting from scratch, it is easiest to install the Apple Command Line Tools.  Download the binary for your version of OSX here: [Apple Developer Downloads](https://developer.apple.com/downloads/)

Install Node and NPM on OSX (tested on 10.10). [NodeJS](http://nodejs.org/) is the scripting language used for these tools and must be installed on your system.  We also need [ffmpeg](https://www.ffmpeg.org/) for file metadata probing.  The quickest way to do this is via [brew](http://brew.sh/).  To install [brew](http://brew.sh/), then [NodeJS](http://nodejs.org/), and lastly [ffmpeg](https://www.ffmpeg.org/) run the following on the command line:
```
ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
brew install node
brew install ffmpeg
sudo npm install -g coffee-script
```

### Install

```
sudo npm install -g mediatidy
```

## Usage
Add media folder to **mediatidy** you would like to process with:

```
mediatidy paths-update
```

Let's tidy up those media directories!

```
mediatidy update
```

As always options etc. can be brought up with:

```
mediatidy --help
```
