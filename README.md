# mediatidy

This project is under development. Things are broken.

## Setup

Be sure you have NodeJS and coffee-script installed.
```
brew install node
sudo npm install -g coffee-script
```

FFmpeg is required for analyzing video files.  Install FFmpeg via brew:
```
brew install ffmpeg
```

Clone the repo, cd into the dir, install npm modules.
```
git clone git@github.com:tkdan235/mediatidy.git
cd mediatidy
npm install
```

## Using mediatidy

Update the config with the path to your movie files:

```
bin/mediatidy config update
```

Update your mediatidy database with your movie files:

```
bin/mediatidy movies update
```
