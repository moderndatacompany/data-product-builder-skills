#!/usr/bin/env python3
"""
Clean up seed models - remove duplicate column_types blocks and fix closing parenthesis
"""

import re
from pathlib import Path

MODELS_DIR = Path(__file__).parent / "models" / "seeds"

def clean_seed_model(sql_file: Path) -> bool:
    """Remove duplicate column_types block and fix syntax"""
    
    print(f"Cleaning: {sql_file.name}")
    
    content = sql_file.read_text()
    
    # Remove the duplicate pattern: )\n  ,\n    column_types (...)\n  )
    # This appears after the columns() block
    pattern = r'(\n\s+\)\s*\n\s*)\),\s*\n\s+column_types\s*\([^)]*\)[^)]*\)\s*\)'
    
    def fix_closing(match):
        # Just keep the first closing parenthesis
        return match.group(1) + ')'
    
    new_content = re.sub(pattern, fix_closing, content, flags=re.DOTALL)
    
    if new_content == content:
        print(f"  ℹ️  No changes needed")
        return False
    
    # Write back
    sql_file.write_text(new_content)
    print(f"  ✅ Cleaned up duplicate blocks")
    return True

def main():
    print("=" * 80)
    print("SGWS Web Analytics - Clean Up Seed Models")
    print("=" * 80)
    print()
    
    sql_files = sorted(MODELS_DIR.glob('*.sql'))
    
    success_count = 0
    skip_count = 0
    
    for sql_file in sql_files:
        if clean_seed_model(sql_file):
            success_count += 1
        else:
            skip_count += 1
        print()
    
    print("=" * 80)
    print(f"✅ Cleaned: {success_count}, Skipped: {skip_count}, Total: {len(sql_files)}")
    print("=" * 80)

if __name__ == "__main__":
    main()
