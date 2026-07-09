# MySQL SSL certificates

The `vulcan-mysql` container expects these files to exist at runtime:

- `server.crt`
- `server.key`

They are typically **generated locally** (and often gitignored), which is why they may not appear in the repository tree.

## Quick self-signed (development)

From `examples/snowflake_tpch/docker/`:

```bash
mkdir -p ssl
openssl req -x509 -newkey rsa:4096 \
  -keyout ssl/server.key \
  -out ssl/server.crt \
  -days 365 -nodes \
  -subj "/CN=localhost"
```

## Reference

See `mysql/README.md` for the canonical Vulcan MySQL SSL/TLS configuration and notes.


