"""
Create ONESOURCEPLUS schema in Snowflake (required for RFM models).

Run from cobs/:  source .env && python scripts/create_onesourceplus_schema.py

If you see "Schema GENSLER.ONESOURCEPLUS does not exist" in vulcan plan,
run this first, then insert_to_snowflake_sales.py, then fast_create_insert_customer.py.
"""
import os

_SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
_COBS_ROOT = os.path.normpath(os.path.join(_SCRIPT_DIR, '..'))

try:
    from dotenv import load_dotenv
    load_dotenv(os.path.join(_COBS_ROOT, '.env'))
except ImportError:
    pass

import snowflake.connector

# Resolve key path (env or cobs/snowflake_key.p8)
_key_env = os.environ.get('SNOWFLAKE_PRIVATE_KEY_PATH')
for p in (_key_env, os.path.join(_COBS_ROOT, _key_env or ''), os.path.join(_COBS_ROOT, 'snowflake_key.p8')):
    if p and os.path.exists(p):
        KEY_PATH = os.path.abspath(p)
        break
else:
    KEY_PATH = os.path.abspath(_key_env or os.path.join(_COBS_ROOT, 'snowflake_key.p8'))

PASSPHRASE = os.environ.get('SNOWFLAKE_PRIVATE_KEY_PASSPHRASE') or None


def main():
    if not os.path.exists(KEY_PATH):
        raise SystemExit(f"Private key not found: {KEY_PATH}. Set SNOWFLAKE_PRIVATE_KEY_PATH in .env or run from cobs/.")

    # Load key so connector gets a key object (avoids NoneType with path-only on some setups)
    from cryptography.hazmat.backends import default_backend
    from cryptography.hazmat.primitives.serialization import load_pem_private_key
    with open(KEY_PATH, 'rb') as f:
        key = load_pem_private_key(f.read(), password=(PASSPHRASE.encode() if PASSPHRASE else None), backend=default_backend())

    db = os.environ.get('SNOWFLAKE_DATABASE', 'GENSLER')
    print(f"Creating schema ONESOURCEPLUS in database {db} (if not exists)...")

    conn = snowflake.connector.connect(
        user=os.environ.get('SNOWFLAKE_USER', 'SHREYA'),
        account=os.environ.get('SNOWFLAKE_ACCOUNT', 'EQZOTUQ-JCA67320'),
        warehouse=os.environ.get('SNOWFLAKE_WAREHOUSE', 'COMPUTE_WH'),
        database=db,
        authenticator='SNOWFLAKE_JWT',
        private_key=key,
    )
    cur = conn.cursor()
    try:
        cur.execute("CREATE SCHEMA IF NOT EXISTS ONESOURCEPLUS")
        print("Schema ONESOURCEPLUS created or already exists.")
    except snowflake.connector.errors.ProgrammingError as e:
        if '42501' in str(e) or 'Insufficient privileges' in str(e):
            print(
                "\nConnection OK but your role cannot create a schema in this database.\n"
                "Ask your Snowflake admin to run:\n"
                "  CREATE SCHEMA IF NOT EXISTS GENSLER.ONESOURCEPLUS;\n"
                "or grant your role CREATE SCHEMA on database GENSLER.\n"
            )
        raise
    finally:
        cur.close()
        conn.close()


if __name__ == '__main__':
    main()
