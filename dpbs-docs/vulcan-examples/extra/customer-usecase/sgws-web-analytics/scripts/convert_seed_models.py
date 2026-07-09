#!/usr/bin/env python3
"""
Convert all seed models to have explicit column definitions with metadata
"""

import csv
import re
from pathlib import Path
from typing import List, Tuple, Dict

# Configuration
MODELS_DIR = Path(__file__).parent / "models" / "seeds"
SEEDS_DIR = Path(__file__).parent / "seeds"
OWNER = "rohitrajtmdcio"

# Type inference based on column name patterns and sample data
def infer_column_type(col_name: str, sample_values: List[str]) -> str:
    """Infer SQL type from column name and sample values"""
    col_lower = col_name.lower()
    
    # Filter out empty/null values for analysis
    non_empty = [v for v in sample_values if v and v.strip() and v.lower() not in ('null', 'none', '')]
    
    if not non_empty:
        return 'STRING'
    
    # Check patterns in column names
    if any(pattern in col_lower for pattern in ['_id', '_sk', '_no', '_key', 'number']):
        # Try to detect if it's numeric
        try:
            for val in non_empty[:5]:
                int(val)
            return 'BIGINT'
        except:
            return 'STRING'
    
    if any(pattern in col_lower for pattern in ['_date', '_dt', 'date_']):
        return 'DATE'
    
    if 'timestamp' in col_lower or '_ts' in col_lower or col_lower.endswith('_at'):
        return 'TIMESTAMP'
    
    if any(pattern in col_lower for pattern in ['amt', 'price', 'cost', 'revenue', 'net', 'gross']):
        return 'DECIMAL(18, 2)'
    
    if any(pattern in col_lower for pattern in ['qty', 'quantity', 'count', 'cases', 'bottles']):
        return 'DECIMAL(15, 3)'
    
    if any(pattern in col_lower for pattern in ['_flg', '_ind', 'flag', 'is_', 'has_']):
        return 'STRING'  # Often Y/N or true/false stored as string
    
    if any(pattern in col_lower for pattern in ['_cd', '_code', 'status']):
        return 'STRING'
    
    if any(pattern in col_lower for pattern in ['percent', 'pct', 'rate']):
        return 'DECIMAL(10, 4)'
    
    # Analyze sample values
    try:
        # Check if all samples are integers
        for val in non_empty[:10]:
            int(val)
        return 'BIGINT'
    except:
        pass
    
    try:
        # Check if all samples are decimals
        for val in non_empty[:10]:
            float(val)
        return 'DOUBLE'
    except:
        pass
    
    # Default to STRING
    return 'STRING'

def read_csv_columns(csv_path: Path) -> Tuple[List[str], List[List[str]]]:
    """Read CSV file and return column names and sample data"""
    
    # Determine delimiter
    delimiter = ','
    if csv_path.suffix == '.tsv' or 'browser' in csv_path.name or 'event' in csv_path.name:
        delimiter = '\t'
    
    try:
        with open(csv_path, 'r', encoding='utf-8') as f:
            reader = csv.reader(f, delimiter=delimiter)
            headers = next(reader)
            
            # Read first 20 rows for type inference
            samples = []
            for i, row in enumerate(reader):
                if i >= 20:
                    break
                samples.append(row)
            
            return headers, samples
    except Exception as e:
        print(f"  ⚠️  Error reading {csv_path}: {e}")
        return [], []

def get_seed_description(model_name: str) -> str:
    """Generate description for seed model based on name"""
    name_lower = model_name.lower()
    
    if 'customer' in name_lower:
        return 'Static customer reference data from source system'
    elif 'sales' in name_lower:
        return 'Historical sales transaction seed data for testing and development'
    elif 'order' in name_lower:
        return 'Historical order transaction seed data for testing and development'
    elif 'product' in name_lower or 'item' in name_lower:
        return 'Product catalog seed data with item details and classifications'
    elif 'site' in name_lower:
        return 'Distribution site location reference data'
    elif 'store' in name_lower:
        return 'Retail store location reference data'
    elif 'browser' in name_lower:
        return 'Browser lookup reference data from Adobe Analytics'
    elif 'operating' in name_lower or 'os' in name_lower:
        return 'Operating system lookup reference data from Adobe Analytics'
    elif 'resolution' in name_lower:
        return 'Screen resolution lookup reference data'
    elif 'language' in name_lower:
        return 'Language code lookup reference data'
    elif 'country' in name_lower:
        return 'Country code lookup reference data'
    elif 'event' in name_lower:
        return 'Adobe Analytics event type reference data'
    elif 'badge' in name_lower:
        return 'Product badge classification reference data'
    elif 'hit_data' in name_lower:
        return 'Adobe Analytics clickstream raw hit data seed'
    elif 'pricing' in name_lower:
        return 'Product pricing reference data'
    elif 'salesperson' in name_lower:
        return 'Sales representative assignment reference data'
    elif 'roadnet' in name_lower:
        return 'Geographic location and routing reference data'
    else:
        return f'Reference data seed for {model_name}'

def convert_seed_model(sql_file: Path) -> bool:
    """Convert a seed model to have explicit columns and metadata"""
    
    print(f"Converting: {sql_file.name}")
    
    # Read current model
    content = sql_file.read_text()
    
    # Extract model name
    name_match = re.search(r'name\s+(\w+\.\w+)', content)
    if not name_match:
        print(f"  ❌ Could not extract model name")
        return False
    
    model_name = name_match.group(1)
    simple_name = model_name.split('.')[-1]
    
    # Extract seed path and settings
    path_match = re.search(r"path\s+'([^']+)'", content)
    if not path_match:
        print(f"  ❌ Could not extract seed path")
        return False
    
    seed_path = path_match.group(1)
    
    # Determine CSV file path
    csv_filename = seed_path.split('/')[-1]
    csv_path = SEEDS_DIR / csv_filename
    
    if not csv_path.exists():
        print(f"  ⚠️  CSV file not found: {csv_path}")
        return False
    
    # Read CSV columns
    headers, samples = read_csv_columns(csv_path)
    
    if not headers:
        print(f"  ❌ No headers found in CSV")
        return False
    
    # Transpose samples for column-wise analysis
    col_samples = []
    for i in range(len(headers)):
        col_samples.append([row[i] if i < len(row) else '' for row in samples])
    
    # Infer types
    columns_with_types = []
    for header, sample_vals in zip(headers, col_samples):
        col_type = infer_column_type(header, sample_vals)
        columns_with_types.append((header, col_type))
    
    # Determine delimiter for csv_settings
    delimiter = ','
    if csv_path.suffix == '.tsv' or 'browser' in csv_filename or 'event' in csv_filename:
        delimiter = '\\t'
    
    # Generate new model content
    description = get_seed_description(simple_name)
    
    # Determine tags based on model type
    if any(word in simple_name.lower() for word in ['sales', 'order', 'fact']):
        tags = "('seed', 'reference_data', 'transactional', 'testing')"
    elif any(word in simple_name.lower() for word in ['customer', 'site', 'store', 'product', 'item']):
        tags = "('seed', 'reference_data', 'dimension', 'master_data')"
    elif any(word in simple_name.lower() for word in ['browser', 'operating', 'resolution', 'language', 'country', 'event']):
        tags = "('seed', 'reference_data', 'adobe_analytics', 'lookup')"
    else:
        tags = "('seed', 'reference_data', 'lookup')"
    
    terms = f"('seed.{simple_name.lower()}', 'reference.{simple_name.lower()}')"
    
    # Build column list for SELECT
    column_list = ',\n  '.join([f"{col}" for col, _ in columns_with_types])
    
    # Build column descriptions (for first 15 columns)
    col_descriptions = []
    for col, col_type in columns_with_types[:15]:
        desc = f"{col.replace('_', ' ').title()} ({col_type})"
        col_descriptions.append(f"    {col} = '{desc}'")
    
    # Generate new model
    new_content = f"""MODEL (
  name {model_name},
  kind SEED (
    path '{seed_path}',
    csv_settings (
      delimiter = '{delimiter}'
    )
  ),
  owner '{OWNER}',
  description '{description}',
  tags {tags},
  terms {terms},
  
  -- ==================== COLUMN DESCRIPTIONS ====================
  column_descriptions (
{chr(10).join(col_descriptions)}
  )
);

-- ============================================================================
-- SEED DATA: {simple_name}
-- ============================================================================
-- Total Columns: {len(columns_with_types)}
-- Source: {csv_filename}
-- ============================================================================

SELECT
  {column_list}
FROM SEED();
"""
    
    # Write back
    sql_file.write_text(new_content)
    print(f"  ✅ Converted with {len(columns_with_types)} columns")
    return True

def main():
    print("=" * 80)
    print("SGWS Web Analytics - Seed Model Conversion")
    print("=" * 80)
    print()
    print(f"Models Directory: {MODELS_DIR}")
    print(f"Seeds Directory: {SEEDS_DIR}")
    print()
    
    # Get all seed model files
    sql_files = sorted(MODELS_DIR.glob('*.sql'))
    
    if not sql_files:
        print("❌ No seed model files found!")
        return
    
    print(f"Found {len(sql_files)} seed models to convert")
    print("-" * 80)
    print()
    
    success_count = 0
    error_count = 0
    
    for sql_file in sql_files:
        try:
            if convert_seed_model(sql_file):
                success_count += 1
            else:
                error_count += 1
        except Exception as e:
            print(f"  ❌ Error: {e}")
            error_count += 1
        print()
    
    print("=" * 80)
    print("✅ Seed Model Conversion Complete!")
    print("=" * 80)
    print(f"  Successfully converted: {success_count}")
    print(f"  Errors: {error_count}")
    print(f"  Total: {len(sql_files)}")
    print()
    print("Next: Run 'vulcan info' to validate all models")
    print("=" * 80)

if __name__ == "__main__":
    main()
