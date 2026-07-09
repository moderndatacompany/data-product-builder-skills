#!/usr/bin/env python3
"""
Fix seed model structure - CORRECTED VERSION
Match gensler-qualitrics exact pattern with proper indentation
"""

import re
from pathlib import Path

MODELS_DIR = Path(__file__).parent.parent / "models" / "seeds"

def fix_seed_structure(sql_file: Path) -> bool:
    """Restructure seed model to match gensler pattern exactly"""
    
    print(f"Fixing: {sql_file.name}")
    
    content = sql_file.read_text()
    
    # Extract key components
    name_match = re.search(r"name\s+([\w.]+)", content)
    path_match = re.search(r"path\s+'([^']+)'", content)
    delimiter_match = re.search(r"delimiter\s*=\s*'([^']+)'", content)
    columns_match = re.search(r"columns\s*\((.*?)\n\s*\)", content, re.DOTALL)
    owner_match = re.search(r"owner\s+'([^']+)'", content)
    desc_match = re.search(r"description\s+'([^']+)'", content)
    tags_match = re.search(r"tags\s+\(([^)]+)\)", content)
    terms_match = re.search(r"terms\s+\(([^)]+)\)", content)
    col_desc_match = re.search(r"column_descriptions\s*\((.*?)\n\s*\)", content, re.DOTALL)
    
    if not all([name_match, path_match, columns_match]):
        print(f"  ⚠️  Missing required fields")
        return False
    
    name = name_match.group(1)
    path = path_match.group(1)
    delimiter = delimiter_match.group(1) if delimiter_match else ','
    columns_raw = columns_match.group(1).strip()
    owner = owner_match.group(1) if owner_match else 'rohitrajtmdcio'
    description = desc_match.group(1) if desc_match else 'Reference data seed'
    tags = tags_match.group(1) if tags_match else "'seed', 'reference_data'"
    terms = terms_match.group(1) if terms_match else "'seed', 'reference'"
    col_desc_raw = col_desc_match.group(1).strip() if col_desc_match else ''
    
    # Fix column indentation
    columns_lines = [line.strip() for line in columns_raw.split('\n') if line.strip()]
    columns_block = ',\n'.join(['        ' + line.lstrip() for line in columns_lines])
    
    # Fix column descriptions indentation
    col_desc_lines = [line.strip() for line in col_desc_raw.split('\n') if line.strip() and not line.strip().startswith('--')]
    col_desc_block = ',\n'.join(['    ' + line.lstrip() for line in col_desc_lines])
    
    # Build new structure following gensler pattern EXACTLY
    new_model = f"""MODEL (
  name {name},
  kind SEED (
    path '{path}'"""
    
    # Add csv_settings only if needed
    if delimiter != ',' or '.tsv' in path:
        new_model += f""",
    csv_settings (
      delimiter = '{delimiter}'
    )"""
    
    new_model += f"""
  ),
  owner '{owner}',
  description '{description}',
  tags ({tags}),
  terms ({terms}),
  columns (
{columns_block}
  )"""
    
    # Add column_descriptions if exists
    if col_desc_block:
        new_model += f""",
  
  -- ==================== COLUMN DESCRIPTIONS ====================
  column_descriptions (
{col_desc_block}
  )"""
    
    new_model += "\n);\n"
    
    # Add the SELECT statement
    select_match = re.search(r"SELECT(.*?)FROM SEED\(\);", content, re.DOTALL)
    if select_match:
        # Extract column names from SELECT
        select_columns = select_match.group(1).strip()
        
        # Add comments before SELECT
        new_model += "\n-- ============================================================================\n"
        new_model += f"-- SEED DATA: {sql_file.stem.replace('_seed', '').upper()}\n"
        new_model += "-- ============================================================================\n\n"
        new_model += f"SELECT\n{select_columns}\nFROM SEED();\n"
    
    # Write back
    sql_file.write_text(new_model)
    print(f"  ✅ Restructured correctly")
    return True

def main():
    print("=" * 80)
    print("SGWS Web Analytics - Fix Seed Model Structure (CORRECTED)")
    print("=" * 80)
    print("Matching gensler-qualitrics pattern: columns() OUTSIDE kind SEED")
    print()
    
    sql_files = sorted(MODELS_DIR.glob('*.sql'))
    
    success_count = 0
    
    for sql_file in sql_files:
        try:
            if fix_seed_structure(sql_file):
                success_count += 1
        except Exception as e:
            print(f"  ❌ Error: {e}")
            import traceback
            traceback.print_exc()
        print()
    
    print("=" * 80)
    print(f"✅ Complete! Fixed: {success_count}/{len(sql_files)}")
    print("=" * 80)
    print("\nVerify with: head -25 models/seeds/browser_seed.sql")

if __name__ == "__main__":
    main()
