#!/usr/bin/env python3
"""
PHASE 2: Fix problematic column names in seed CSV/TSV files
- Replace dots with underscores
- Replace hyphens with underscores  
- Remove leading underscores
- Replace spaces with underscores
"""

from pathlib import Path
import csv
import re

SEEDS_DIR = Path(__file__).parent.parent / "seeds"

def sanitize_column_name(col_name: str) -> str:
    """Convert column name to valid SQL identifier"""
    # Replace problematic characters with underscore
    sanitized = col_name.replace('.', '_')
    sanitized = sanitized.replace('-', '_')
    sanitized = sanitized.replace(' ', '_')
    sanitized = sanitized.replace('(', '_')
    sanitized = sanitized.replace(')', '_')
    
    # Remove leading underscores (but keep if it's __metadata)
    while sanitized.startswith('_') and not sanitized.startswith('__'):
        sanitized = sanitized[1:]
    
    # Remove multiple consecutive underscores
    sanitized = re.sub(r'_+', '_', sanitized)
    
    # Remove trailing underscores
    sanitized = sanitized.rstrip('_')
    
    return sanitized

def fix_csv_headers(seed_file: Path) -> tuple:
    """Fix headers in CSV/TSV file"""
    
    print(f"Fixing: {seed_file.name}")
    
    try:
        # Read the file
        with open(seed_file, 'r', encoding='utf-8') as f:
            lines = f.readlines()
        
        if not lines:
            print(f"  ⚠️  Empty file")
            return (False, 0)
        
        # Get delimiter
        delimiter = '\t' if seed_file.suffix == '.tsv' else ','
        
        # Parse header
        header_line = lines[0].strip()
        columns = [col.strip() for col in header_line.split(delimiter)]
        
        # Sanitize column names
        sanitized_columns = [sanitize_column_name(col) for col in columns]
        
        # Check if any changes were made
        if columns == sanitized_columns:
            print(f"  ✅ Already clean")
            return (True, 0)
        
        # Count changes
        changes = sum(1 for i in range(len(columns)) if columns[i] != sanitized_columns[i])
        
        # Build new header line
        new_header = delimiter.join(sanitized_columns)
        
        # Write back
        lines[0] = new_header + '\n'
        with open(seed_file, 'w', encoding='utf-8') as f:
            f.writelines(lines)
        
        print(f"  ✅ Fixed {changes} column names")
        return (True, changes)
        
    except Exception as e:
        print(f"  ❌ Error: {e}")
        return (False, 0)

def main():
    print("=" * 80)
    print("PHASE 2: FIX PROBLEMATIC COLUMN NAMES IN SEED FILES")
    print("=" * 80)
    print()
    
    seed_files = sorted(list(SEEDS_DIR.glob('*.csv')) + list(SEEDS_DIR.glob('*.tsv')))
    
    total_fixed = 0
    total_changes = 0
    
    for seed_file in seed_files:
        success, changes = fix_csv_headers(seed_file)
        if success and changes > 0:
            total_fixed += 1
            total_changes += changes
        print()
    
    print("=" * 80)
    print(f"✅ PHASE 2 COMPLETE")
    print("=" * 80)
    print(f"  Files fixed: {total_fixed}")
    print(f"  Total column renames: {total_changes}")
    print()
    print("Next: Phase 3 - Rebuild SQL models with clean column names")

if __name__ == "__main__":
    main()
