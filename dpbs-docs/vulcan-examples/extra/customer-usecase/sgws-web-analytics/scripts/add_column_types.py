#!/usr/bin/env python3
"""
Add column types to all seed models
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

def update_seed_model(sql_file: Path) -> bool:
    """Update seed model to include column_types in SEED definition"""
    
    print(f"Updating: {sql_file.name}")
    
    content = sql_file.read_text()
    
    # Check if already has column_types in SEED block
    if re.search(r'kind SEED.*column_types', content, re.DOTALL):
        print(f"  ✅ Already has column_types")
        return True
    
    # Extract column info from descriptions
    columns = extract_column_info(content)
    
    if not columns:
        print(f"  ⚠️  No columns found in descriptions")
        return False
    
    # Build column_types block
    col_types_lines = []
    for col_name, col_type in columns:
        col_types_lines.append(f"      {col_name} = {col_type}")
    
    col_types_block = ",\n".join(col_types_lines)
    
    # Find and replace the SEED block
    # Match pattern: kind SEED (\n    path ...,\n    csv_settings (...)\n  ),
    seed_pattern = r'(kind SEED\s*\(\s*path[^,]+,\s*csv_settings\s*\([^)]+\)\s*\))'
    
    def add_column_types(match):
        seed_block = match.group(1)
        # Remove the closing parenthesis
        seed_block = seed_block.rstrip(')')
        # Add column_types before closing
        new_block = f"{seed_block},\n    column_types (\n{col_types_block}\n    )\n  )"
        return new_block
    
    new_content = re.sub(seed_pattern, add_column_types, content, flags=re.DOTALL)
    
    if new_content == content:
        print(f"  ⚠️  Could not match SEED pattern")
        return False
    
    # Write back
    sql_file.write_text(new_content)
    print(f"  ✅ Added column_types for {len(columns)} columns")
    return True

def main():
    print("=" * 80)
    print("SGWS Web Analytics - Add Column Types to Seed Models")
    print("=" * 80)
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
            if result == True and 'Already has' in open(sql_file).read():
                skip_count += 1
            elif result:
                success_count += 1
            else:
                error_count += 1
        except Exception as e:
            print(f"  ❌ Error: {e}")
            error_count += 1
        print()
    
    print("=" * 80)
    print("✅ Column Types Addition Complete!")
    print("=" * 80)
    print(f"  Successfully updated: {success_count}")
    print(f"  Errors/Skipped: {error_count + skip_count}")
    print(f"  Total: {len(sql_files)}")
    print()
    print("Verify with: head -30 models/seeds/browser_seed.sql")

if __name__ == "__main__":
    main()
