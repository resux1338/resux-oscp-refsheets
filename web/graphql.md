# GraphQL checks

## Schema / introspection
```bash
curl -s http://<IP>/graphql -H 'Content-Type: application/json' \
  -d '{"query":"{__schema{types{name fields{name}}}}"}'
```
- Query the same object as two users; schema visibility ≠ data access.
- Try `/graphiql`, `/v1/graphql` if the app hints at them.
