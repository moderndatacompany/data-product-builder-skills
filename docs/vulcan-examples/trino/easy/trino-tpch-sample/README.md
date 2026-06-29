# Trino Data Product Deployment

This example shows how to deploy a Vulcan data product with connection type `trino`.

The current recommended pattern in this example is to use `projection` in the resource file and inject the Trino connection details as environment variables. The `config.yaml` then reads those values with `env_var(...)`.

## How It Works

1. Store the Trino connection values in a secret.
2. Use `spec.use.projection` in `domain-resource.yaml` to map secret values into environment variables.
3. Read those environment variables in `config.yaml` under the Trino gateway connection.

This keeps credentials out of the project config and makes deployment easier across environments.

## Generate the Trino Password

Create the Trino password value with:

```sh
echo '{"cluster": "cluster-name", "apikey": "your api key ", "tenant": "tenant name"}' | base64
```

Use the generated output as the Trino password value in your secret.

## Example Trino Secret

Create a secret like this:

```yaml
name: trino-connection-secret
version: v2alpha
type: secret
layer: user
secret:
  type: key-value
  data:
    HOST: ""
    USER: ""
    CATALOG: ""
    PASSWORD: ""
```

Set:

- `HOST` as the Trino host
- `USER` as the Trino user
- `CATALOG` as the Trino catalog
- `PASSWORD` as the base64 value generated from the command above

## Example `config.yaml`

```yaml
name: trino-analytics-prod
display_name: Trino Analytics
tenant: your-tenant

model_defaults:
  dialect: trino

gateways:
  default:
    connection:
      type: trino
      host: "{{ env_var('TRINO_HOST', '') }}"
      port: 7432
      user: "{{ env_var('TRINO_USER', '') }}"
      catalog: "{{ env_var('TRINO_CATALOG', '') }}"
      http_scheme: https
      method: basic
      password: "{{ env_var('TRINO_PASSWORD', '') }}"
      verify: true
```

## Example `domain-resource.yaml`

```yaml
version: v1alpha
type: vulcan
name: trino-analytics-prod

spec:
  runAsUser: your-user
  compute: your-compute
  engine: trino
  repo:
    url: https://bitbucket.org/your-org/your-repo
    baseDir: path/to/project
    secret: your-tenant:git-sync
  use:
    projection:
      secrets:
        - id: your-tenant:trino-connection-secret
          contextAlias: trn
      projections:
        envVars:
          - key: TRINO_HOST
            template: "{{ secrets['trn'].HOST | base64_decode }}"
          - key: TRINO_USER
            template: "{{ secrets['trn'].USER | base64_decode }}"
          - key: TRINO_CATALOG
            template: "{{ secrets['trn'].CATALOG | base64_decode }}"
          - key: TRINO_PASSWORD
            template: "{{ secrets['trn'].PASSWORD | base64_decode }}"
```

## Secret Keys Expected by Projection

Your secret should provide these keys:

- `HOST`
- `USER`
- `CATALOG`
- `PASSWORD`

The projection maps these secret values into:

- `TRINO_HOST`
- `TRINO_USER`
- `TRINO_CATALOG`
- `TRINO_PASSWORD`

## Summary

For Trino deployments in Vulcan, keep the connection block in `config.yaml` and use `projection` in `domain-resource.yaml` to inject credentials securely at runtime.
