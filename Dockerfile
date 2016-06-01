FROM node:5
MAINTAINER Octoblu <docker@octoblu.com>

ENV NPM_CONFIG_LOGLEVEL error

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

COPY . /usr/src/app
RUN npm install --production

CMD [ "node", "--max_old_space_size=256", "command-dispatch.js" ]
