# GA4 Analytics - BigQuery Configuration

## Overview
This project has been configured to use **BigQuery** with DataOS depot integration, following the same pattern as the Gensler Qualtrics project but adapted for GA4 analytics use cases.

## Key Configuration Changes

### 1. **config.yaml** - Production Configuration

#### From (config.local.yaml):
```yaml
gateways:
  default:
    connection:
      type: bigquery
      method: service-account
      project: tmdc-platform-engineering
      keyfile: /Users/shreyasikarwar/.../bigquery_key.json
    state_connection:
      type: postgres
      host: localhost
      port: 5431
      ...
```

#### To (config.yaml):
```yaml
gateways:
  default:
    connection:
      type: depot
      address: dataos://bigquery
```

**Why?** 
- Depot abstraction handles authentication and connection management
- No need to specify keyfile or state_connection manually
- Works seamlessly in DataOS production environment

---

### 2. **domain-resource.yaml** - DataOS Resource Definition

Key sections configured for BigQuery:

```yaml
spec:
  engine: bigquery  # ✅ Changed from 'snowflake'
  depots:
    - dataos://bigquery?purpose=rw  # ✅ Using bigquery depot
  workflow:
    schedule:
      crons:
      - '0 0 * * *'  # Daily at midnight UTC
```

**Important Changes:**
- `engine: bigquery` - Uses the BigQuery Vulcan stack we created
- `dataos://bigquery` - References the depot configured in `depot/bigquery/depots.yaml`
- Daily schedule appropriate for GA4 data refresh patterns

---

### 3. **Model Defaults**

```yaml
model_defaults:
  dialect: bigquery
  start: '2020-11-02'  # Matches GA4 sample data
  cron: '@daily'
```

- `dialect: bigquery` - All models use BigQuery SQL syntax
- Start date matches your GA4 sample data
- Daily refresh schedule

---

## Depot Configuration Reference

The project uses the depot configured in:
```
depot/bigquery/
├── depots.yaml     # Depot definition
└── secrets.yaml    # BigQuery service account credentials
```

**Depot Details:**
- **Name:** `bigquery`
- **Project:** `tmdc-platform-engineering`
- **Secret:** `engineering:bigquery-secret`
- **Authentication:** Service account with `gcp_json_key`

---

## Engine Stack Reference

The project uses the BigQuery engine stack:
```
.artefacts/stacks/bigquery-engine.yaml
```

**Key Mapping (lines 379-407):**
```yaml
{%- if depot_details.type == "bigquery" %}
- name: {{ projection.name }}_config.yaml
  contents: |
    connection:
      type: bigquery
      method: service-account
      project: {{ depot_details.spec.project }}
      keyfile: /etc/dataos/secret/{{ projection.name }}_gcp_keyfile.json

{%- if secrets.gcp_json_key %}
- name: {{ projection.name }}_gcp_keyfile.json
  contents: !!binary {{ secrets.gcp_json_key }}
{%- endif %}
```

---

## Comparison: Snowflake vs BigQuery

| Aspect | Snowflake (Gensler) | BigQuery (GA4) |
|--------|-------------------|--------------|
| **Engine** | `snowflake` | `bigquery` |
| **Depot** | `dataos://snowflakevulcan2` | `dataos://bigquery` |
| **Dialect** | `dialect: snowflake` | `dialect: bigquery` |
| **Auth** | Key-pair (private key + passphrase) | Service account (JSON key) |
| **Project** | Warehouse + Database + Schema | Project + Dataset + Table |
| **Secret Field** | `key` + `passphrase` + `username` | `gcp_json_key` |

---

## How to Deploy

### 1. **Local Development** (using config.local.yaml)
```bash
# Use local BigQuery credentials
vulcan plan
vulcan run
```

### 2. **Production Deployment** (using config.yaml + domain-resource.yaml)
```bash
# Apply the Vulcan resource to DataOS
dataos-ctl apply -f domain-resource.yaml

# Monitor the deployment
dataos-ctl get -t vulcan -n ga4-analytics
```

---

## External Models

The project references GA4 BigQuery export tables in `external_models.yaml`:

```yaml
- name: '`tmdc-platform-engineering`.`vulcan_ga4_demo`.`events_table`'
  columns:
    event_name: STRING
    event_timestamp: INT64
    user_pseudo_id: FLOAT64
    # ... GA4 schema
```

This allows Vulcan models to reference the raw GA4 events table without managing it directly.

---

## Next Steps

1. ✅ **Depot configured** - `depot/bigquery/`
2. ✅ **Engine stack created** - `.artefacts/stacks/bigquery-engine.yaml`
3. ✅ **Config created** - `ga4-project/config.yaml`
4. ✅ **Domain resource created** - `ga4-project/domain-resource.yaml`

**Ready to deploy!** 🚀

### Testing the Configuration

```bash
# 1. Test locally first
cd ga4-project
vulcan plan --config config.local.yaml

# 2. Test with depot configuration
vulcan plan --config config.yaml

# 3. Deploy to DataOS
dataos-ctl apply -f domain-resource.yaml
```

---

## Troubleshooting

### Issue: "Depot not found"
**Solution:** Ensure the depot is applied first:
```bash
cd depot/bigquery
dataos-ctl apply -f secrets.yaml
dataos-ctl apply -f depots.yaml
```

### Issue: "Authentication failed"
**Solution:** Check that the secret contains valid `gcp_json_key`:
```bash
dataos-ctl get secret -n engineering:bigquery-secret
```

### Issue: "Project not found"
**Solution:** Verify the BigQuery project ID in `depots.yaml` matches your GCP project.

---

## References

- [Vulcan Documentation](https://vulcan.dataos.io)
- [BigQuery Depot Configuration](../depot/bigquery/)
- [BigQuery Engine Stack](../.artefacts/stacks/bigquery-engine.yaml)
- [Gensler Qualtrics Example](../customer-usecase/gensler-qualitrics/)

