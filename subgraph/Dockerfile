FROM node:16

COPY package.json yarn.lock ./
RUN yarn install

COPY index.js schema.graphql ./

CMD ["node", "index.js"]
