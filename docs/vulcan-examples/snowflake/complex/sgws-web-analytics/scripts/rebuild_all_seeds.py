#!/usr/bin/env python3
"""
COMPREHENSIVE FIX: Rebuild all seed models to EXACTLY match gensler pattern
"""

import re
from pathlib import Path

MODELS_DIR = Path(__file__).parent.parent / "models" / "seeds"
SEEDS_DIR = Path(__file__).parent.parent / "seeds"

def read_csv_columns(csv_path: Path) -> list:
    """Read column names from CSV/TSV file"""
    try:
        with open(csv_path, 'r', encoding='utf-8') as f:
            header = f.readline().strip()
            delimiter = '\t' if csv_path.suffix == '.tsv' else ','
            return [col.strip() for col in header.split(delimiter)]
    except Exception as e:
        print(f"    Warning: Could not read {csv_path.name}: {e}")
        return []

def infer_type(col_name: str) -> str:
    """Infer column type from name"""
    col_lower = col_name.lower()
    
    if any(p in col_lower for p in ['_id', '_sk', '_no', 'number', '_key', 'id']):
        return 'BIGINT'
    elif any(p in col_lower for p in ['_date', '_dt', 'date_']):
        return 'DATE'
    elif 'timestamp' in col_lower or '_ts' in col_lower or col_lower.endswith('_at'):
        return 'TIMESTAMP'
    elif any(p in col_lower for p in ['amt', 'price', 'cost', 'revenue', 'net', 'gross']):
        return 'DECIMAL(18, 2)'
    elif any(p in col_lower for p in ['qty', 'quantity', 'count', 'cases', 'bottles']):
        return 'DECIMAL(15, 3)'
    elif any(p in col_lower for p in ['percent', 'pct', 'rate']):
        return 'DECIMAL(10, 4)'
    else:
        return 'VARCHAR'

def rebuild_seed_model(sql_file: Path) -> bool:
    """Rebuild seed model from scratch following gensler pattern EXACTLY"""
    
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
    
    # Read columns from actual CSV/TSV file
    columns = read_csv_columns(seed_file)
    
    if not columns:
        print(f"  ⚠️  No columns found in {seed_file.name}")
        return False
    
    # Build columns block with types
    columns_lines = []
    for i, col in enumerate(columns):
        col_type = infer_type(col)
        if i < len(columns) - 1:
            columns_lines.append(f"        {col} {col_type},")
        else:
            columns_lines.append(f"        {col} {col_type}")
    
    columns_block = '\n'.join(columns_lines)
    
    # Build SELECT statement
    select_lines = []
    for i, col in enumerate(columns):
        if i < len(columns) - 1:
            select_lines.append(f"  {col},")
        else:
            select_lines.append(f"  {col}")
    
    select_block = '\n'.join(select_lines)
    
    # Determine delimiter
    delimiter = '\\t' if seed_file.suffix == '.tsv' else ','
    
    # Build the complete model following gensler pattern EXACTLY
    new_content = f"""MODEL (
  name {name},
  kind SEED (
    path '{rel_path}'"""
    
    # Add csv_settings if TSV or if delimiter is not comma
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
    
    # Write the new content
    sql_file.write_text(new_content)
    print(f"  ✅ Rebuilt with {len(columns)} columns")
    return True

def main():
    print("=" * 80)
    print("SGWS Web Analytics - COMPREHENSIVE SEED MODEL REBUILD")
    print("=" * 80)
    print("Rebuilding ALL models to EXACTLY match gensler-qualitrics pattern")
    print()
    
    sql_files = sorted(MODELS_DIR.glob('*.sql'))
    
    success_count = 0
    
    for sql_file in sql_files:
        try:
            if rebuild_seed_model(sql_file):
                success_count += 1
        except Exception as e:
            print(f"  ❌ Error: {e}")
            import traceback
            traceback.print_exc()
        print()
    
    print("=" * 80)
    print(f"✅ Complete! Rebuilt: {success_count}/{len(sql_files)}")
    print("=" * 80)
    print("\nVerify with:")
    print("  head -25 models/seeds/browser_seed.sql")
    print("  vulcan info")

if __name__ == "__main__":
    main()
