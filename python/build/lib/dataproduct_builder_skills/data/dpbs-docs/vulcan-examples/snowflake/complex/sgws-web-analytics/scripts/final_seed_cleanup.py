#!/usr/bin/env python3
"""
Final cleanup: Remove duplicate column_types blocks from all seed models
Follow gensler-qualitrics pattern: use columns() only, change STRING to VARCHAR
"""

import re
from pathlib import Path

MODELS_DIR = Path(__file__).parent / "models" / "seeds"

def fix_seed_model(sql_file: Path) -> bool:
    """Fix seed model to match gensler pattern"""
    
    print(f"Fixing: {sql_file.name}")
    
    content = sql_file.read_text()
    
    # Check if already fixed
    if 'column_types' not in content:
        print(f"  ✅ Already clean")
        return True
    
    # Pattern: find and remove the duplicate "),\n column_types(...)" block
    # Match from end of columns() to end of column_types()
    pattern = r'(\n\s+\)\s*\n\s*\))\s*,\s*\n\s+column_types\s*\([^)]+\)\s*\)'
    
    new_content = re.sub(pattern, r'\1', content)
    
    # Change STRING to VARCHAR to match reference
    new_content = new_content.replace(' STRING,', ' VARCHAR,')
    new_content = new_content.replace(' STRING\n', ' VARCHAR\n')
    
    # Fix column_descriptions - ensure commas between items
    desc_pattern = r"(column_descriptions\s*\([^)]+)\n(\s+\w+\s*=)"
    new_content = re.sub(desc_pattern, r'\1,\n\2', new_content)
    
    if new_content == content:
        print(f"  ⚠️  No changes made")
        return False
    
    # Write back
    sql_file.write_text(new_content)
    print(f"  ✅ Fixed")
    return True

def main():
    print("=" * 80)
    print("SGWS Web Analytics - Final Seed Model Cleanup")
    print("=" * 80)
    print("Pattern: columns() only, VARCHAR type, proper commas")
    print()
    
    sql_files = sorted(MODELS_DIR.glob('*.sql'))
    
    success_count = 0
    
    for sql_file in sql_files:
        if fix_seed_model(sql_file):
            success_count += 1
        print()
    
    print("=" * 80)
    print(f"✅ Complete! Fixed/Verified: {success_count}/{len(sql_files)}")
    print("=" * 80)
    print("\nVerify with:")
    print("  head -30 models/seeds/browser_seed.sql")
    print("  head -50 models/seeds/v_d_customer_seed.sql")

if __name__ == "__main__":
    main()
