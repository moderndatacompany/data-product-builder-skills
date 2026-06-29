#!/usr/bin/env python3
"""
PHASE 6: Proper Type Inference from Actual CSV Data
Read actual values from CSV files to correctly infer column types
"""

from pathlib import Path
import csv
import re

MODELS_DIR = Path(__file__).parent.parent / "models" / "seeds"
SEEDS_DIR = Path(__file__).parent.parent / "seeds"

def infer_type_from_values(values: list, col_name: str) -> str:
    """Infer SQL type from actual data values"""
    
    # Remove None/empty values
    non_empty = [v for v in values if v and str(v).strip() and str(v).strip().lower() not in ('', 'null', 'none', 'nan')]
    
    if not non_empty:
        return 'VARCHAR'
    
    # Sample first 100 values
    sample = non_empty[:100]
    
    # Check if all values are integers
    all_int = True
    all_numeric = True
    has_decimal = False
    
    for val in sample:
        val_str = str(val).strip()
        
        # Check for decimal point
        if '.' in val_str:
            has_decimal = True
            all_int = False
        
        # Try to convert to number
        try:
            float(val_str)
        except (ValueError, TypeError):
            all_numeric = False
            all_int = False
            break
    
    # If all values are numeric
    if all_numeric:
        col_lower = col_name.lower()
        
        # Check for date/timestamp patterns
        if any(p in col_lower for p in ['_date', '_dt', 'date_']):
            # Check if values look like dates (YYYYMMDD or similar)
            sample_val = str(sample[0])
            if len(sample_val) == 8 and sample_val.isdigit():
                return 'DATE'
            else:
                return 'VARCHAR'  # Date in other format
        
        if 'timestamp' in col_lower or '_ts' in col_lower:
            return 'TIMESTAMP'
        
        # Decimal types
        if has_decimal:
            if any(p in col_lower for p in ['amt', 'price', 'cost', 'revenue', 'net', 'gross']):
                return 'DECIMAL(18, 2)'
            elif any(p in col_lower for p in ['qty', 'quantity', 'cases', 'bottles']):
                return 'DECIMAL(15, 3)'
            elif any(p in col_lower for p in ['percent', 'pct', 'rate']):
                return 'DECIMAL(10, 4)'
            else:
                return 'DECIMAL(18, 4)'
        
        # Integer types
        if all_int:
            return 'BIGINT'
    
    # Default to VARCHAR for string data
    return 'VARCHAR'

def read_csv_with_types(csv_path: Path, max_rows: int = 200) -> tuple:
    """Read CSV/TSV and infer types from actual data"""
    
    try:
        delimiter = '\t' if csv_path.suffix == '.tsv' else ','
        
        with open(csv_path, 'r', encoding='utf-8', errors='ignore') as f:
            reader = csv.reader(f, delimiter=delimiter)
            header = next(reader)
            
            # Read sample rows
            rows = []
            for i, row in enumerate(reader):
                if i >= max_rows:
                    break
                rows.append(row)
            
            if not rows:
                # No data, use name-based inference
                return [(col, infer_type_from_values([], col)) for col in header]
            
            # Transpose to get columns
            columns_data = []
            for col_idx, col_name in enumerate(header):
                values = [row[col_idx] if col_idx < len(row) else None for row in rows]
                inferred_type = infer_type_from_values(values, col_name)
                columns_data.append((col_name, inferred_type))
            
            return columns_data
    
    except Exception as e:
        print(f"    Error reading {csv_path.name}: {e}")
        return []

def rebuild_seed_with_correct_types(sql_file: Path) -> bool:
    """Rebuild seed model with types inferred from actual CSV data"""
    
    print(f"Rebuilding: {sql_file.name}")
    
    # Extract metadata from existing file
    content = sql_file.read_text()
    
    name_match = re.search(r"name\s+([\w.]+)", content)
    path_match = re.search(r"path\s+'([^']+)'", content)
    owner_match = re.search(r"owner\s+'([^']+)'", content)
    desc_match = re.search(r"description\s+'([^']+)'", content)
    tags_match = re.search(r"tags\s+\(([^)]+)\)", content)
    terms_match = re.search(r"terms\s+\(([^)]+)\)", content)
    
    if not all([name_match, path_match]):
        print(f"  ⚠️  Missing required fields")
        return False
    
    name = name_match.group(1)
    rel_path = path_match.group(1)
    owner = owner_match.group(1) if owner_match else 'rohitrajtmdcio'
    description = desc_match.group(1) if desc_match else 'Reference data seed'
    tags = tags_match.group(1) if tags_match else "'seed', 'reference_data'"
    terms = terms_match.group(1) if terms_match else "'seed', 'reference'"
    
    # Determine actual file path
    seed_file = SEEDS_DIR / rel_path.replace('../../seeds/', '')
    
    # Read columns WITH TYPE INFERENCE FROM DATA
    columns_with_types = read_csv_with_types(seed_file)
    
    if not columns_with_types:
        print(f"  ⚠️  No columns found in {seed_file.name}")
        return False
    
    # Build columns block
    columns_lines = []
    for i, (col_name, col_type) in enumerate(columns_with_types):
        if i < len(columns_with_types) - 1:
            columns_lines.append(f"        {col_name} {col_type},")
        else:
            columns_lines.append(f"        {col_name} {col_type}")
    
    columns_block = '\n'.join(columns_lines)
    
    # Build SELECT statement
    select_lines = []
    for i, (col_name, _) in enumerate(columns_with_types):
        if i < len(columns_with_types) - 1:
            select_lines.append(f"  {col_name},")
        else:
            select_lines.append(f"  {col_name}")
    
    select_block = '\n'.join(select_lines)
    
    # Determine delimiter
    delimiter = '\\t' if seed_file.suffix == '.tsv' else ','
    
    # Build the complete model
    new_content = f"""MODEL (
  name {name},
  kind SEED (
    path '{rel_path}'"""
    
    # Add csv_settings if TSV
    if delimiter != ',':
        new_content += f""",
    csv_settings (
      delimiter = '{delimiter}'
    )"""
    
    new_content += f"""
  ),
  owner '{owner}',
  description '{description}',
  tags ({tags}),
  terms ({terms}),
  columns (
{columns_block}
  )
);

-- ============================================================================
-- SEED DATA: {sql_file.stem.replace('_seed', '').upper()}
-- ============================================================================

SELECT
{select_block}
FROM SEED();
"""
    
    sql_file.write_text(new_content)
    print(f"  ✅ Rebuilt with {len(columns_with_types)} columns (types from data)")
    return True

def main():
    print("=" * 80)
    print("PHASE 6: REBUILD WITH CORRECT TYPES FROM ACTUAL DATA")
    print("=" * 80)
    print("Reading actual CSV/TSV data to infer correct types...")
    print()
    
    sql_files = sorted(MODELS_DIR.glob('*.sql'))
    
    success_count = 0
    
    for sql_file in sql_files:
        try:
            if rebuild_seed_with_correct_types(sql_file):
                success_count += 1
        except Exception as e:
            print(f"  ❌ Error: {e}")
            import traceback
            traceback.print_exc()
        print()
    
    print("=" * 80)
    print(f"✅ PHASE 6 COMPLETE! Rebuilt: {success_count}/{len(sql_files)}")
    print("=" * 80)
    print("\nTypes inferred from actual data values, not just column names")
    print("Next: vulcan run")

if __name__ == "__main__":
    main()
