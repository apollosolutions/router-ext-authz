FROM node:16

COPY package.json yarn.lock ./
RUN yarn install

COPY privatekey.pem publickey.pem ./
COPY index.js ./

CMD ["node", "index.js"]
