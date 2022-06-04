import { ApolloServer, gql } from "apollo-server";
import { buildSubgraphSchema } from "@apollo/subgraph";

const server = new ApolloServer({
  schema: buildSubgraphSchema({
    typeDefs: gql(`
      type Query {
        hello: String
      }
    `),
    resolvers: {
      Query: {
        hello: (_, __, { userId, username }) => {
          return `${username} (id: ${userId})!`;
        },
      },
    },
  }),
  context({ req }) {
    console.log(Object.entries(req.headers));
    return {
      userId: req.headers["x-user-id"],
      username: req.headers["x-user-name"],
    };
  },
});

const { url } = await server.listen(4001);
console.log(url);
