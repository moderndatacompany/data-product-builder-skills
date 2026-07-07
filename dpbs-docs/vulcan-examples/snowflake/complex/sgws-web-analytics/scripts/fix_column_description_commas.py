#!/usr/bin/env python3
"""
Fix missing commas in column_descriptions for all seed models
"""

import re
from pathlib import Path

MODELS_DIR = Path(__file__).parent.parent / "models" / "seeds"

def fix_column_descriptions(sql_file: Path) -> bool:
    """Add missing commas between column description lines"""
    
    print(f"Fixing: {sql_file.name}")
    
    content = sql_file.read_text()
    
    # Check if file has column_descriptions
    if 'column_descriptions' not in content:
        print(f"  ℹ️  No column_descriptions found")
        return False
    
    # Find the column_descriptions block
    desc_pattern = r'(column_descriptions\s*\()(.*?)(\n\s*\))'
    
    def fix_commas(match):
        prefix = match.group(1)
        desc_block = match.group(2)
        suffix = match.group(3)
        
        # Split into lines
        lines = desc_block.split('\n')
        fixed_lines = []
        
        for i, line in enumerate(lines):
            line = line.rstrip()
            
            # Skip empty lines and comment lines
            if not line.strip() or line.strip().startswith('--'):
                fixed_lines.append(line)
                continue
            
            # If this is not the last non-empty line and doesn't end with comma
            if i < len(lines) - 1:
                # Check if next line is not empty
                next_nonempty = False
                for j in range(i + 1, len(lines)):
                    if lines[j].strip() and not lines[j].strip().startswith('--'):
                        next_nonempty = True
                        break
                
                if next_nonempty and not line.endswith(','):
                    line = line + ','
            
            fixed_lines.append(line)
        
        return prefix + '\n'.join(fixed_lines) + suffix
    
    new_content = re.sub(desc_pattern, fix_commas, content, flags=re.DOTALL)
    
    if new_content == content:
        print(f"  ✅ Already correct")
        return True
    
    # Write back
    sql_file.write_text(new_content)
    print(f"  ✅ Fixed missing commas")
    return True

def main():
    print("=" * 80)
    print("SGWS Web Analytics - Fix Missing Commas in column_descriptions")
    print("=" * 80)
    print()
    
    sql_files = sorted(MODELS_DIR.glob('*.sql'))
    
    success_count = 0
    
    for sql_file in sql_files:
        if fix_column_descriptions(sql_file):
            success_count += 1
        print()
    
    print("=" * 80)
    print(f"✅ Complete! Processed: {success_count}/{len(sql_files)}")
    print("=" * 80)
    print("\nVerify with: vulcan info")

if __name__ == "__main__":
    main()
