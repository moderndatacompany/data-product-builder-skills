# MySQL

Your semantic layer speaks the MySQL wire protocol, so anything that can talk to MySQL can query it: the `mysql` shell, DBeaver, JetBrains DataGrip, MySQL Workbench, scripts, exports, internal tools.

Pick the interface that matches how you already work.

---

## Option 1: MySQL Shell

If you don't have the shell installed, grab it for your OS from the official docs:

```
https://dev.mysql.com/doc/mysql-shell/8.4/en/mysql-shell-install.html
```

Connect with your tenant details:

```bash
mysql -h tcp.{instance_name} -P 3306 -u {username} -p'{apikey}' --enable-cleartext-plugin {tenant_name}.{dataproduct_name}
```

`--enable-cleartext-plugin` is required: the API key is sent as the password, and TLS encrypts the channel.

Once connected, explore your semantic layer with standard SQL:

```sql
-- List all available semantic models
SHOW TABLES;

-- View the structure of one
DESCRIBE table_name;

-- List columns
SHOW COLUMNS FROM table_name;
```

---

## Option 2: DBeaver or other IDEs

DBeaver, DataGrip, MySQL Workbench, and most SQL IDEs support MySQL connections. Use these values in the new-connection dialog:

| Field | Value |
|---|---|
| Host | `tcp.{instance_name}` |
| Port | `3306` |
| Username | `{username}` |
| Password | `{apikey}` |
| Database | `{tenant_name}.{dataproduct_name}` |

{% hint style="info" %}
<!-- vale Vulcan.Marketing = NO -->
Enable **cleartext authentication** in the IDE's advanced or SSL settings. Without it, the connection fails immediately at handshake.
<!-- vale Vulcan.Marketing = YES -->
{% endhint %}

---

## Troubleshooting

<details>
<summary>Common issues</summary>

**`Authentication plugin 'mysql_clear_password' cannot be loaded`**

<!-- vale Vulcan.Marketing = NO -->
Cleartext auth isn't enabled. In the shell, add `--enable-cleartext-plugin`. In a GUI IDE, find the option under **Driver properties** or **SSL/Advanced settings** and turn it on.
<!-- vale Vulcan.Marketing = YES -->

**`Unknown database '{tenant}.{dataproduct}'`**

The database string must contain a dot: `{tenant_name}.{dataproduct_name}`. Just the data product name on its own won't resolve.

**`SHOW TABLES` is empty**

No semantic models have been applied yet. Run `vulcan plan` and confirm at least one model exists in `models/semantics/`.

**Connection refused or timeout**

Confirm `tcp.{instance_name}` resolves and that port 3306 isn't blocked by a corporate firewall or VPN policy.

</details>
