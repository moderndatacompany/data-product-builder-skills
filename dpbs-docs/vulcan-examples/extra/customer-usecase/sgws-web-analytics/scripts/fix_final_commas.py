#!/usr/bin/env python3
"""
Final fix: Properly format columns with single commas between items
"""

import re
from pathlib import Path

MODELS_DIR = Path(__file__).parent.parent / "models" / "seeds"

def fix_commas_in_columns(sql_file: Path) -> bool:
    """Fix comma placement in columns and column_descriptions blocks"""
    
    print(f"Fixing: {sql_file.name}")
    
    content = sql_file.read_text()
    
    # Fix columns block - add commas between lines, no comma on last line
    def fix_block(match):
        prefix = match.group(1)
        block_content = match.group(2)
        suffix = match.group(3)
        
        lines = [line.rstrip() for line in block_content.split('\n')]
        fixed_lines = []
        
        for i, line in enumerate(lines):
            if not line.strip():
                continue
            
            # Remove any existing trailing commas
            line = re.sub(r',+\s*$', '', line)
            
            # Add comma if not the last item
            if i < len(lines) - 1:
                # Check if there's a next non-empty line
                has_next = any(l.strip() for l in lines[i+1:])
                if has_next:
                    line = line + ','
            
            fixed_lines.append(line)
        
        return prefix + '\n'.join(fixed_lines) + suffix
    
    # Fix columns block
    content = re.sub(
        r'(columns\s*\()(.*?)(\n\s*\))',
        fix_block,
        content,
        flags=re.DOTALL
    )
    
    # Fix column_descriptions block
    content = re.sub(
        r'(column_descriptions\s*\()(.*?)(\n\s*\))',
        fix_block,
        content,
        flags=re.DOTALL
    )
    
    sql_file.write_text(content)
    print(f"  ✅ Fixed comma placement")
    return True

def main():
    print("=" * 80)
    print("SGWS Web Analytics - Final Comma Fix")
    print("=" * 80)
    print()
    
    sql_files = sorted(MODELS_DIR.glob('*.sql'))
    
    for sql_file in sql_files:
        fix_commas_in_columns(sql_file)
    
    print()
    print("=" * 80)
    print(f"✅ Complete! Fixed {len(sql_files)} files")
    print("=" * 80)

if __name__ == "__main__":
    main()
