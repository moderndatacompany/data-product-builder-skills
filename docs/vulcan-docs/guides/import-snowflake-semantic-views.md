# Import Snowflake Semantic Views

If you have a semantic view defined natively in Snowflake, you can import it into a Vulcan project instead of writing `kind: semantic` YAML by hand. Vulcan reads the view definition directly from Snowflake, translates it to the Vulcan semantic format, and writes one YAML file per table under `models/snowflake_semantic/`. The result is a standard Vulcan semantic layer with dimensions, measures, segments, joins, and REST/GraphQL/MySQL-wire endpoints.

This guide covers the full workflow from a blank directory to a running REST API against an imported semantic view.

***

## Prerequisites

- Vulcan installed with the Snowflake engine extra (`vulcan-<version>-py3-none-any.whl[snowflake]`)
- A Snowflake connection configured in your `config.yaml`
- A Snowflake Semantic View created in Snowflake (requires Snowflake Enterprise edition or higher)

***

## Initialize your project

If you are starting from scratch:

```bash
mkdir my-project && cd my-project
vulcan init
```

This creates the standard project layout:

```
my-project/
├── config.yaml
└── models/
```

If you already have a Vulcan project, skip this step.

Edit `config.yaml` to add your Snowflake gateway. Use the key-pair JWT method recommended for production:

```yaml
gateways:
  default:
    connection:
      type: snowflake
      account: "{{ env_var('SNOWFLAKE_ACCOUNT') }}"
      user: "{{ env_var('SNOWFLAKE_USER') }}"
      authenticator: snowflake_jwt
      private_key_path: ./snowflake_key.p8
      private_key_passphrase: "{{ env_var('SNOWFLAKE_KEY_PASSPHRASE') }}"
      warehouse: "{{ env_var('SNOWFLAKE_WAREHOUSE') }}"
      database: "{{ env_var('SNOWFLAKE_DATABASE') }}"
    state_connection:
      type: duckdb
      database: ./.state/vulcan.db

model_defaults:
  dialect: snowflake
```

For password-based authentication or key-pair setup instructions, see [Set up authentication](../technical-manuals/snowflake-engine.md#32-set-up-authentication).

***

## Import the semantic view

Run `import_semantic_view` and pass the name of the semantic view:

```bash
vulcan import_semantic_view MY_SEMANTIC_VIEW --connection default
```

To target a specific database and schema, use a fully qualified name:

```bash
vulcan import_semantic_view MYDB.GOLD.MY_SEMANTIC_VIEW --connection default
```

Vulcan calls `SYSTEM$READ_YAML_FROM_SEMANTIC_VIEW()` on Snowflake and translates the result into Vulcan's `kind: semantic` format. The generated files land under:

```
models/snowflake_semantic/MY_SEMANTIC_VIEW/
├── ORDERS.yml
├── CUSTOMER.yml
└── LINEITEM.yml
```

Each file is a standard Vulcan semantic model file. You can add measures, adjust joins, or add `ai_context`, just like any hand-authored semantic model.

***

## Generate external model stubs

Vulcan needs the column schema of the underlying Snowflake tables that the semantic view references. Run:

```bash
vulcan create_external_models
```

This writes `inputs.yaml` to the project root. Each entry lists a source table with its columns and types, which Vulcan uses for join inference and query transpilation.

***

## Fix inputs.yaml

The generated `inputs.yaml` has two issues that must be corrected before `vulcan plan` will succeed.

**Before:**

```yaml
- name: "'MYDB'.'SCHEMA'.'ORDERS'"
  columns:
    O_ORDERKEY: DECIMAL(38, 0)
    O_TOTALPRICE: DECIMAL(12, 2)
```

**After:**

```yaml
- name: MYDB.SCHEMA.ORDERS
  dialect: snowflake
  grain:
    - O_ORDERKEY
  columns:
    O_ORDERKEY: DECIMAL(38, 0)
    O_TOTALPRICE: DECIMAL(12, 2)
```

Apply these fixes to every entry in the file:

| Fix | Why |
|---|---|
| Remove the quotes around the table name | Quoted identifiers break table resolution during planning |
| Add `dialect: snowflake` | Ensures the correct SQL transpilation dialect for each external table |
| Add `grain: [<primary_key>]` | Required for join inference; use the primary key column of each table |

{% hint style="warning" %}
**Known limitation:** The extra quotes around table names in the generated `inputs.yaml` are a known issue being tracked for a future release. Until it is resolved, unquote each table name manually before running `vulcan plan`.
{% endhint %}

***

## Plan

```bash
vulcan plan
```

Review the output and confirm. Vulcan registers all imported semantic models and makes them queryable.

***

## Query via the REST API

Start the API server:

```bash
vulcan api
```

Query a measure:

```bash
curl -X POST http://localhost:8000/api/v1/query/semantic/rest \
  -H 'Content-Type: application/json' \
  -d '{
    "query": {
      "measures": ["ORDERS.ORDER_COUNT"]
    }
  }'
```

Add a dimension:

```bash
curl -X POST http://localhost:8000/api/v1/query/semantic/rest \
  -H 'Content-Type: application/json' \
  -d '{
    "query": {
      "measures": ["ORDERS.ORDER_COUNT"],
      "dimensions": ["ORDERS.O_ORDERSTATUS"]
    }
  }'
```

Use a segment (imported from a Snowflake filter):

```bash
curl -X POST http://localhost:8000/api/v1/query/semantic/rest \
  -H 'Content-Type: application/json' \
  -d '{
    "query": {
      "measures": ["ORDERS.ORDER_COUNT"],
      "segments": ["ORDERS.HIGH_VALUE"]
    }
  }'
```

{% hint style="info" %}
Snowflake stores unquoted identifiers in UPPERCASE. Measure names, dimension names, and segment names in API queries must match the UPPERCASE identifiers in the imported YAML files exactly.
{% endhint %}

For the full REST, GraphQL, and MySQL wire protocol reference, see [Vulcan API Guide](vulcan_api_guide.md).

***

## Re-import after a view change

If the Snowflake Semantic View definition changes, remove the old translated files and start the import from scratch:

```bash
# Remove old translated models
rm -rf models/snowflake_semantic/MY_SEMANTIC_VIEW/

# Remove inputs.yaml so it is fully regenerated
rm inputs.yaml

# Re-import from Snowflake
vulcan import_semantic_view MY_SEMANTIC_VIEW --connection default

# Regenerate external model stubs
vulcan create_external_models
```

Then reapply the `inputs.yaml` fixes (dialect, grain, and unquote) and run `vulcan plan`.

***

## Related links

- [`import_semantic_view`](../cli.md#import_semantic_view): full CLI reference and options
- [`create_external_models`](../cli.md#create_external_models): generates `inputs.yaml` from the connected warehouse
- [Snowflake Engine Manual](../technical-manuals/snowflake-engine.md): identifier casing rules, permissions, and troubleshooting
- [Semantic Models](../components/semantics/README.md): editing and extending the generated YAML files
- [Vulcan API Guide](vulcan_api_guide.md): REST, GraphQL, and MySQL wire protocol query reference
