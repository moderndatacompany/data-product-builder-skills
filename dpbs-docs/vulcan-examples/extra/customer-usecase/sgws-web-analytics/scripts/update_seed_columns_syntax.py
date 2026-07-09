#!/usr/bin/env python3
"""
Update all seed models to use correct columns() syntax following gensler-qualitrics pattern
"""

import re
from pathlib import Path
from typing import List, Tuple

# Configuration
MODELS_DIR = Path(__file__).parent / "models" / "seeds"

def extract_column_info(content: str) -> List[Tuple[str, str]]:
    """Extract column names and types from column descriptions"""
    
    # Extract column descriptions block
    desc_match = re.search(r'column_descriptions\s*\((.*?)\n\s*\)', content, re.DOTALL)
    if not desc_match:
        return []
    
    desc_block = desc_match.group(1)
    
    # Parse each line to extract column name and type
    columns = []
    for line in desc_block.split('\n'):
        line = line.strip()
        if not line or line.startswith('--'):
            continue
        
        # Format: column_name = 'Description (TYPE)'
        match = re.match(r'(\w+)\s*=\s*[\'"].*?\(([^)]+)\)[\'"]', line)
        if match:
            col_name = match.group(1)
            col_type = match.group(2).strip()
            columns.append((col_name, col_type))
    
    return columns

def extract_all_columns_from_select(content: str) -> List[str]:
    """Extract ALL column names from SELECT statement"""
    
    # Find SELECT statement
    select_match = re.search(r'SELECT\s+(.*?)\s+FROM\s+SEED', content, re.DOTALL | re.IGNORECASE)
    if not select_match:
        return []
    
    select_clause = select_match.group(1)
    
    # Extract column names
    columns = []
    for line in select_clause.split('\n'):
        line = line.strip()
        if not line or line.startswith('--'):
            continue
        
        # Remove trailing comma
        col = line.rstrip(',').strip()
        if col:
            columns.append(col)
    
    return columns

def get_type_for_column(col_name: str, typed_columns: List[Tuple[str, str]]) -> str:
    """Get type for a column, with fallback to inference"""
    
    # First check if we have it in typed_columns
    for name, col_type in typed_columns:
        if name == col_name:
            return col_type
    
    # Fallback type inference
    col_lower = col_name.lower()
    
    if any(pattern in col_lower for pattern in ['_id', '_sk', '_no', 'number', '_key']):
        return 'BIGINT'
    elif any(pattern in col_lower for pattern in ['_date', '_dt', 'date_']):
        return 'DATE'
    elif 'timestamp' in col_lower or '_ts' in col_lower or col_lower.endswith('_at'):
        return 'TIMESTAMP'
    elif any(pattern in col_lower for pattern in ['amt', 'price', 'cost', 'revenue', 'net', 'gross']):
        return 'DECIMAL(18, 2)'
    elif any(pattern in col_lower for pattern in ['qty', 'quantity', 'count', 'cases', 'bottles']):
        return 'DECIMAL(15, 3)'
    elif any(pattern in col_lower for pattern in ['percent', 'pct', 'rate']):
        return 'DECIMAL(10, 4)'
    else:
        return 'VARCHAR'  # Default to VARCHAR (same as reference)

def update_seed_model(sql_file: Path) -> bool:
    """Update seed model to use columns() syntax following gensler pattern"""
    
    print(f"Updating: {sql_file.name}")
    
    content = sql_file.read_text()
    
    # Check if already uses columns() syntax correctly
    if re.search(r'kind SEED.*\n\s*columns\s*\(', content, re.DOTALL):
        print(f"  ✅ Already uses columns() syntax")
        return True
    
    # Extract column info from descriptions (top 15)
    typed_columns = extract_column_info(content)
    
    # Extract ALL columns from SELECT statement
    all_columns = extract_all_columns_from_select(content)
    
    if not all_columns:
        print(f"  ⚠️  No columns found in SELECT statement")
        return False
    
    print(f"  📊 Found {len(all_columns)} total columns")
    
    # Build columns list with types for ALL columns
    columns_with_types = []
    for col in all_columns:
        col_type = get_type_for_column(col, typed_columns)
        columns_with_types.append((col, col_type))
    
    # Build columns block following gensler pattern
    col_lines = []
    for col_name, col_type in columns_with_types:
        col_lines.append(f"        {col_name} {col_type}")
    
    columns_block = ",\n".join(col_lines)
    
    # Find and replace the entire SEED block
    # Pattern: kind SEED (\n    path ...,\n    csv_settings (...),\n    column_types (...)\n  )
    seed_pattern = r'kind SEED\s*\([^)]*path[^)]+[^)]*(?:csv_settings[^)]+\)[^)]*)?(?:column_types[^)]+\)[^)]*)*\)'
    
    def replace_seed_block(match):
        seed_block = match.group(0)
        
        # Extract path
        path_match = re.search(r"path\s+'([^']+)'", seed_block)
        if not path_match:
            return seed_block
        
        path = path_match.group(1)
        
        # Extract delimiter if exists
        delimiter = ','
        if '.tsv' in path or re.search(r"delimiter\s*=\s*'\\t'", seed_block):
            delimiter = '\\t'
        
        # Build new SEED block
        new_block = f"""kind SEED (
    path '{path}',
    csv_settings (
      delimiter = '{delimiter}'
    ),
    columns (
{columns_block}
    )
  )"""
        return new_block
    
    new_content = re.sub(seed_pattern, replace_seed_block, content, flags=re.DOTALL)
    
    if new_content == content:
        print(f"  ⚠️  Could not match SEED pattern")
        return False
    
    # Write back
    sql_file.write_text(new_content)
    print(f"  ✅ Updated with columns() syntax - {len(columns_with_types)} columns")
    return True

def main():
    print("=" * 80)
    print("SGWS Web Analytics - Update Seed Models to columns() Syntax")
    print("=" * 80)
    print("Following pattern from: gensler-qualitrics/models/flattening/sharepoint_metadata.sql")
    print()
    
    # Get all seed model files
    sql_files = sorted(MODELS_DIR.glob('*.sql'))
    
    if not sql_files:
        print("❌ No seed model files found!")
        return
    
    print(f"Found {len(sql_files)} seed models to update")
    print("-" * 80)
    print()
    
    success_count = 0
    skip_count = 0
    error_count = 0
    
    for sql_file in sql_files:
        try:
            result = update_seed_model(sql_file)
            if result:
                if 'Already uses' in str(result):
                    skip_count += 1
                else:
                    success_count += 1
            else:
                error_count += 1
        except Exception as e:
            print(f"  ❌ Error: {e}")
            error_count += 1
        print()
    
    print("=" * 80)
    print("✅ Seed Model Update Complete!")
    print("=" * 80)
    print(f"  Successfully updated: {success_count}")
    print(f"  Already correct: {skip_count}")
    print(f"  Errors: {error_count}")
    print(f"  Total: {len(sql_files)}")
    print()
    print("Verify with: head -40 models/seeds/browser_seed.sql")

if __name__ == "__main__":
    main()
