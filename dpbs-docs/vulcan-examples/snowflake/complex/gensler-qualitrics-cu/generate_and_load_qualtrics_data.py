import pandas as pd
import snowflake.connector
from snowflake.connector.pandas_tools import write_pandas
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.backends import default_backend
import json
import os
from datetime import datetime
from pathlib import Path

def load_json_file(filepath):
    """Load JSON file and return parsed content"""
    with open(filepath, 'r') as f:
        return json.load(f)

def get_survey_files_from_mock_data(mock_data_dir):
    """Get all survey files from mock_data directory
    
    Returns:
        List of tuples: (survey_id, response_file, definition_file, schema_file)
    """
    response_dir = os.path.join(mock_data_dir, 'response')
    definition_dir = os.path.join(mock_data_dir, 'definition')
    schema_dir = os.path.join(mock_data_dir, 'response_schema')
    
    survey_files = []
    
    # Find all JSON files in response directory
    if os.path.exists(response_dir):
        for filename in os.listdir(response_dir):
            if filename.endswith('.json'):
                survey_id = filename.replace('.json', '')
                
                response_file = os.path.join(response_dir, filename)
                definition_file = os.path.join(definition_dir, filename)
                schema_file = os.path.join(schema_dir, filename)
                
                # Only include if all three files exist
                if os.path.exists(response_file) and os.path.exists(definition_file) and os.path.exists(schema_file):
                    survey_files.append((survey_id, response_file, definition_file, schema_file))
                else:
                    print(f"Warning: Missing files for survey {survey_id}")
    
    return survey_files

def load_survey_responses(response_file, survey_id):
    """Load survey responses from JSON file and format for DataFrame"""
    data = load_json_file(response_file)
    responses = data.get('responses', [])
    
    formatted_responses = []
    for response in responses:
        formatted_response = {
            "responseId": response.get("responseId"),
            "values": json.dumps(response.get("values", {})),
            "labels": json.dumps(response.get("labels", {})),
            "displayedFields": json.dumps(response.get("displayedFields", [])),
            "displayedValues": json.dumps(response.get("displayedValues", {})),
            "surveyId": survey_id,
            "created_at": response.get("values", {}).get("recordedDate", datetime.now().isoformat())
        }
        formatted_responses.append(formatted_response)
    
    return formatted_responses

def load_survey_definition(definition_file, survey_id):
    """Load survey definition from JSON file"""
    data = load_json_file(definition_file)
    
    return {
        "survey_id": survey_id,
        "payload": json.dumps(data),
        "created_at": datetime.now().isoformat()
    }

def load_response_schema(schema_file, survey_id):
    """Load response schema from JSON file"""
    data = load_json_file(schema_file)
    
    return {
        "survey_id": survey_id,
        "payload": json.dumps(data),
        "created_at": datetime.now().isoformat()
    }

def load_dataset_from_mock_data(mock_data_dir):
    """Load all Qualtrics data from mock_data directory
    
    Args:
        mock_data_dir: Path to mock_data directory containing response/, definition/, response_schema/
    
    Returns:
        Tuple of (responses_df, definitions_df, schemas_df, survey_metadata)
    """
    all_responses = []
    all_definitions = []
    all_schemas = []
    survey_metadata = []
    
    # Get all survey files
    survey_files = get_survey_files_from_mock_data(mock_data_dir)
    
    if not survey_files:
        raise ValueError(f"No survey files found in {mock_data_dir}")
    
    print(f"Loading data for {len(survey_files)} surveys from {mock_data_dir}...")
    
    for survey_id, response_file, definition_file, schema_file in survey_files:
        # Load responses
        survey_responses = load_survey_responses(response_file, survey_id)
        all_responses.extend(survey_responses)
        
        # Load definition and schema (one per survey)
        all_definitions.append(load_survey_definition(definition_file, survey_id))
        all_schemas.append(load_response_schema(schema_file, survey_id))
        
        survey_metadata.append({
            'survey_id': survey_id,
            'num_responses': len(survey_responses)
        })
        
        print(f"  ✓ Survey {survey_id}: {len(survey_responses)} responses")
    
    responses_df = pd.DataFrame(all_responses)
    definitions_df = pd.DataFrame(all_definitions)
    schemas_df = pd.DataFrame(all_schemas)
    
    print(f"\n✓ Loaded {len(responses_df)} total responses across {len(survey_files)} surveys")
    print(f"✓ Loaded {len(definitions_df)} survey definitions")
    print(f"✓ Loaded {len(schemas_df)} response schemas")
    
    return responses_df, definitions_df, schemas_df, survey_metadata

def main():
    # Configuration - Path to mock_data directory
    script_dir = Path(__file__).parent
    mock_data_dir = script_dir / "mock_data"
    
    # Load actual data from mock_data JSON files
    responses_df, definitions_df, schemas_df, survey_metadata = load_dataset_from_mock_data(
        str(mock_data_dir)
    )
    
    print("\n" + "="*60)
    print(f"TOTAL: {len(responses_df)} responses across {len(survey_metadata)} surveys")
    print("="*60)
    
    print("\nSample of responses data:")
    print(responses_df.head(3))
    print(f"\nResponses DataFrame shape: {responses_df.shape}")
    print(f"Definitions DataFrame shape: {definitions_df.shape}")
    print(f"Schemas DataFrame shape: {schemas_df.shape}")
    
    # ---- Load and decrypt private key from depot secrets ----
    print("\nConnecting to Snowflake...")
    
    # Encrypted private key from secrets.yaml
    encrypted_key = """${SNOWFLAKE_ENCRYPTED_PRIVATE_KEY}"""
    
    passphrase = "shreya"
    
    # Parse the encrypted private key with passphrase
    private_key = serialization.load_pem_private_key(
        encrypted_key.encode(),
        password=passphrase.encode(),
        backend=default_backend()
    )
    
    # Convert to DER format for Snowflake
    private_key_bytes = private_key.private_bytes(
        encoding=serialization.Encoding.DER,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption()
    )
    
    # ---- Snowflake connection using JWT key-pair auth ----
    conn = snowflake.connector.connect(
        account="EQZOTUQ-JCA67320",
        user="SHREYA",
        private_key=private_key_bytes,
        warehouse="COMPUTE_WH",
        database="VULCAN",
        schema="QUALTRICS",  # Using a different schema for Qualtrics data
        role="ACCOUNTADMIN",
        authenticator="snowflake_jwt"
    )
    
    # ---- Explicitly set schema and DROP existing tables ----
    cursor = conn.cursor()
    try:
        cursor.execute("CREATE SCHEMA IF NOT EXISTS VULCAN.QUALTRICS")
        cursor.execute("USE SCHEMA VULCAN.QUALTRICS")
        print("Schema VULCAN.QUALTRICS is ready")
        
        # Drop existing tables to recreate them
        print("\nDropping existing tables...")
        cursor.execute("DROP TABLE IF EXISTS VULCAN.QUALTRICS.QUALTRICS_RESPONSES_RAW")
        print("  ✓ Dropped QUALTRICS_RESPONSES_RAW")
        cursor.execute("DROP TABLE IF EXISTS VULCAN.QUALTRICS.QUALTRICS_DEFINITION")
        print("  ✓ Dropped QUALTRICS_DEFINITION")
        cursor.execute("DROP TABLE IF EXISTS VULCAN.QUALTRICS.QUALTRICS_RESPONSE_SCHEMA")
        print("  ✓ Dropped QUALTRICS_RESPONSE_SCHEMA")
    except Exception as e:
        print(f"Note: {e}")
    finally:
        cursor.close()
    
    # ---- Write all three dataframes to Snowflake ----
    print("\n" + "="*60)
    print("Loading data into Snowflake tables...")
    print("="*60)
    
    # Table 1: Survey Responses
    print(f"\n[1/3] Creating and loading {len(responses_df)} rows to QUALTRICS_RESPONSES_RAW...")
    success1, nchunks1, nrows1, _ = write_pandas(
        conn,
        responses_df,
        table_name="QUALTRICS_RESPONSES_RAW",
        auto_create_table=True
    )
    print(f"  ✓ Success: {success1}, Rows loaded: {nrows1}")
    
    # Table 2: Survey Definitions
    print(f"\n[2/3] Creating and loading {len(definitions_df)} rows to QUALTRICS_DEFINITION...")
    success2, nchunks2, nrows2, _ = write_pandas(
        conn,
        definitions_df,
        table_name="QUALTRICS_DEFINITION",
        auto_create_table=True
    )
    print(f"  ✓ Success: {success2}, Rows loaded: {nrows2}")
    
    # Table 3: Response Schemas
    print(f"\n[3/3] Creating and loading {len(schemas_df)} rows to QUALTRICS_RESPONSE_SCHEMA...")
    success3, nchunks3, nrows3, _ = write_pandas(
        conn,
        schemas_df,
        table_name="QUALTRICS_RESPONSE_SCHEMA",
        auto_create_table=True
    )
    print(f"  ✓ Success: {success3}, Rows loaded: {nrows3}")
    
    # Verify all tables
    print("\n" + "="*60)
    print("Verifying data in Snowflake...")
    print("="*60)
    
    cursor = conn.cursor()
    
    # Check each table
    tables = [
        ("QUALTRICS_RESPONSES_RAW", "ResponseID"),
        ("QUALTRICS_DEFINITION", "Survey definition"),
        ("QUALTRICS_RESPONSE_SCHEMA", "Response schema")
    ]
    
    for table_name, description in tables:
        cursor.execute(f"SELECT COUNT(*) FROM VULCAN.QUALTRICS.{table_name}")
        count = cursor.fetchone()[0]
        print(f"\n✓ {table_name}: {count} rows")
        
        # Show column names first
        cursor.execute(f"DESCRIBE TABLE VULCAN.QUALTRICS.{table_name}")
        cols = [r[0] for r in cursor.fetchall()]
        print(f"  Columns ({len(cols)}): {', '.join(cols)}")
        
        # Show sample data
        if table_name == "QUALTRICS_RESPONSES_RAW":
            cursor.execute(f'SELECT "responseId", "surveyId" FROM VULCAN.QUALTRICS.{table_name} LIMIT 2')
            print(f"  Sample data:")
            for row in cursor.fetchall():
                print(f"    ResponseID: {row[0]}, SurveyID: {row[1]}")
        else:
            cursor.execute(f'SELECT "survey_id" FROM VULCAN.QUALTRICS.{table_name} LIMIT 2')
            print(f"  Sample data:")
            for row in cursor.fetchall():
                print(f"    SurveyID: {row[0]}")
    
    cursor.close()
    conn.close()
    
    print("\n" + "="*60)
    print("✓ All data loaded successfully!")
    print("="*60)
    print(f"\nCreated tables in VULCAN.QUALTRICS schema:")
    print(f"  1. QUALTRICS_RESPONSES_RAW - {nrows1} rows")
    print(f"     Columns: responseId, values, labels, displayedFields, displayedValues, surveyId, created_at")
    print(f"     ✓ Loaded from actual mock data JSON files")
    print(f"  2. QUALTRICS_DEFINITION - {nrows2} rows")
    print(f"     Columns: survey_id, payload, created_at")
    print(f"  3. QUALTRICS_RESPONSE_SCHEMA - {nrows3} rows")
    print(f"     Columns: survey_id, payload, created_at")
    print(f"\nTotal surveys: {len(survey_metadata)}")
    print(f"Total responses: {nrows1}")
    print("\nSurvey details:")
    for meta in survey_metadata:
        print(f"  {meta['survey_id']}: {meta['num_responses']} responses")
    print("\nQuery example:")
    print("  SELECT * FROM VULCAN.QUALTRICS.QUALTRICS_RESPONSES_RAW LIMIT 5;")

if __name__ == "__main__":
    main()

