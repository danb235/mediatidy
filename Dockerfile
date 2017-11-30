FROM node:8.2.1-alpine

# install curl
RUN apk add --no-cache curl git

# App directory
WORKDIR /usr/src/mediatidy

# Create test data directory
RUN mkdir ./test && mkdir ./test/data

# Download sample videos
RUN curl http://www.sample-videos.com/video/mkv/720/big_buck_bunny_720p_10mb.mkv --output "./test/data/Godzilla (1954).mkv"
RUN curl http://www.sample-videos.com/video/mp4/480/big_buck_bunny_480p_10mb.mp4 --output "./test/data/Godzilla (1954).mp4"

# Install Yarn packages
COPY package.json .
COPY yarn.lock .
RUN yarn install --pure-lockfile \
  && yarn cache clean

# Copy app files
COPY bin bin
COPY lib lib
