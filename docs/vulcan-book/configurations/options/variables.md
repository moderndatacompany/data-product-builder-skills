# Variables

Store sensitive information like passwords and API keys without hardcoding them in your configuration files. Use environment variables, `.env` files, or configuration overrides to change settings dynamically.

## Environment variables

Vulcan reads environment variables during configuration. Store secrets outside configuration files and change settings based on who's running Vulcan.

### Using .env files

Vulcan loads environment variables from a `.env` file in your project directory:

```bash
# .env file
SNOWFLAKE_PW=my_secret_password
S3_BUCKET=s3://my-data-bucket/warehouse
DATABASE_URL=postgresql://user:pass@localhost/db

# Override Vulcan configuration values
VULCAN__DEFAULT_GATEWAY=production
VULCAN__MODEL_DEFAULTS__DIALECT=snowflake
```

{% hint style="warning" %}
**Security**

Add `.env` to your `.gitignore` file to avoid committing sensitive information.
{% endhint %}

### Custom .env file location

Specify a custom path using the `--dotenv` CLI flag:

```bash
vulcan --dotenv /path/to/custom/.env plan
```

Or set the `VULCAN_DOTENV_PATH` environment variable:

```bash
export VULCAN_DOTENV_PATH=/path/to/custom/.custom_env
vulcan plan
```

{% hint style="info" %}
The `--dotenv` flag must be placed **before** the subcommand (e.g., `plan`, `run`).
{% endhint %}

### Accessing variables in configuration

{% tabs %}
{% tab title="YAML" %}
Use `{{ env_var('VARIABLE_NAME') }}` syntax:

```yaml
gateways:
  my_gateway:
    connection:
      type: snowflake
      user: admin
      password: "{{ env_var('SNOWFLAKE_PW') }}"
      account: my_account
```
{% endtab %}

{% tab title="Python" %}
Use `os.environ`:

```python
import os
from vulcan.core.config import Config, GatewayConfig, SnowflakeConnectionConfig

config = Config(
    gateways={
        "my_gateway": GatewayConfig(
            connection=SnowflakeConnectionConfig(
                user="admin",
                password=os.environ['SNOWFLAKE_PW'],
                account="my_account",
            ),
        ),
    }
)
```
{% endtab %}

{% endtabs %}

## Configuration overrides

Environment variables have the highest precedence. They override configuration file values when they follow the `VULCAN__` naming convention.

### Override naming structure

Use double underscores `__` to navigate the configuration hierarchy:

```
VULCAN__<ROOT_KEY>__<NESTED_KEY>__<FIELD>=value
```

Example: Override a gateway connection password:

```yaml
# config.yaml
gateways:
  my_gateway:
    connection:
      type: snowflake
      password: dummy_pw  # This will be overridden
```

```bash
# Override with environment variable
export VULCAN__GATEWAYS__MY_GATEWAY__CONNECTION__PASSWORD="real_pw"
```

## Dynamic configuration

### User-based target environment

Use the `{{ user() }}` function to set configuration based on the current user:

{% tabs %}
{% tab title="YAML" %}
```yaml
# Each user gets their own dev environment
default_target_environment: dev_{{ user() }}
```
{% endtab %}

{% tab title="Python" %}
```python
import getpass
from vulcan.core.config import Config

config = Config(
    default_target_environment=f"dev_{getpass.getuser()}",
)
```
{% endtab %}

{% endtabs %}

You can now run `vulcan plan` instead of `vulcan plan dev_username`.
