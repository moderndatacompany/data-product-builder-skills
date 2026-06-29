# Snowflake TPC-H Example (`snowflake_tpchName`)

This example provides a minimal TPC-H project on Snowflake using the built-in `SNOWFLAKE_SAMPLE_DATA` dataset.

## What you get

- SQLMesh models for the core TPC-H tables:
  - `test_db.vulcan_test_project.region`
  - `test_db.vulcan_test_project.nation`
  - `test_db.vulcan_test_project.customer`
  - `test_db.vulcan_test_project.supplier`
  - `test_db.vulcan_test_project.part`
  - `test_db.vulcan_test_project.partsupp`
  - `test_db.vulcan_test_project.orders`
  - `test_db.vulcan_test_project.lineitem`

All models are defined as `VIEW` models and read directly from `SNOWFLAKE_SAMPLE_DATA.TPCH_SF1`.

## Prerequisites

- A Snowflake account with access to `SNOWFLAKE_SAMPLE_DATA`
- Vulcan / SQLMesh installed (per repo docs)

## Configure credentials

Set these environment variables:

- `SNOWFLAKE_ACCOUNT`
- `SNOWFLAKE_USER`
- `SNOWFLAKE_ROLE`
- `SNOWFLAKE_WAREHOUSE`

Optional overrides:

- `SNOWFLAKE_DATABASE` (default `SNOWFLAKE_SAMPLE_DATA`)
- `SNOWFLAKE_SCHEMA` (default `TPCH_SF1`)

### Option A: Password authentication

- Set `SNOWFLAKE_PASSWORD`

### Option B: Key-pair authentication (recommended)

Follow Snowflake’s guide for key-pair auth and rotation: [Snowflake key-pair authentication](https://docs.snowflake.com/en/user-guide/key-pair-auth).

Generate a private/public key pair (example from the Snowflake docs):

```bash
# Unencrypted private key (PKCS#8)
openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out rsa_key.p8 -nocrypt

# Public key
openssl rsa -in rsa_key.p8 -pubout -out rsa_key.pub
```

Assign the public key to your Snowflake user (see the Snowflake guide for details):

```sql
ALTER USER <your_user> SET RSA_PUBLIC_KEY='<public_key_contents_without_delimiters>';
```

Then set:

- `SNOWFLAKE_PRIVATE_KEY_PATH` (path to `rsa_key.p8`)
- `SNOWFLAKE_PRIVATE_KEY_PASSPHRASE` (only if your key is encrypted)

Important:
- **Do not set** `SNOWFLAKE_PASSWORD` when using key-pair auth.

## Run

From the repository root:

```bash
make -C examples/snowflake_tpch infra
make -C examples/snowflake_tpch vulcan-up
vulcan -p examples/snowflake_tpch info
vulcan -p examples/snowflake_tpch plan
```

## Notes

- **Infra**: `make -C examples/snowflake_tpch infra` starts Postgres state store (`localhost:5431`) and MinIO (`localhost:9000`) on the external Docker network `vulcan`.
- **Vulcan services**: `make -C examples/snowflake_tpch vulcan-up` starts the API (`:8000`), transpiler (`:4000`), GraphQL (`:3000`), and MySQL (`:3306`).
- **MySQL TLS certs**: If `MYSQL_SSL_ENABLED=true` (default in this example), generate `docker/ssl/server.crt` and `docker/ssl/server.key`. See `examples/snowflake_tpch/docker/ssl/README.md` (and the canonical `mysql/README.md`).
- **State storage**: This example uses a local Postgres state store by default. Do not store state in Snowflake.
- **Scale factor**: Switch to a different TPCH dataset by setting `SNOWFLAKE_SCHEMA` to `TPCH_SF10`, `TPCH_SF100`, etc. (if available in your account).


