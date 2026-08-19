#!/usr/bin/env python3
"""
Fix missing commas in column_descriptions for ALL models (Bronze, Silver, Gold)
"""

import re
from pathlib import Path

MODELS_DIR = Path(__file__).parent.parent / "models"

def fix_column_descriptions(sql_file: Path) -> bool:
    """Add missing commas between column description and tag lines"""
    
    content = sql_file.read_text()
    
    # Check if file has column_descriptions or column_tags
    if 'column_descriptions' not in content and 'column_tags' not in content:
        return False
    
    changed = False
    
    # Fix column_descriptions block
    desc_pattern = r'(column_descriptions\s*\()(.*?)(\n\s*\))'
    
    def fix_commas(match):
        nonlocal changed
        prefix = match.group(1)
        desc_block = match.group(2)
        suffix = match.group(3)
        
        lines = desc_block.split('\n')
        fixed_lines = []
        
        for i, line in enumerate(lines):
            line = line.rstrip()
            
            if not line.strip() or line.strip().startswith('--'):
                fixed_lines.append(line)
                continue
            
            # Check if there's a next non-empty line
            has_next = False
            for j in range(i + 1, len(lines)):
                if lines[j].strip() and not lines[j].strip().startswith('--'):
                    has_next = True
                    break
            
            # Add comma if needed
            if has_next and not line.endswith(','):
                line = line + ','
                changed = True
            
            fixed_lines.append(line)
        
        return prefix + '\n'.join(fixed_lines) + suffix
    
    new_content = re.sub(desc_pattern, fix_commas, content, flags=re.DOTALL)
    
    # Fix column_tags block
    tags_pattern = r'(column_tags\s*\()(.*?)(\n\s*\))'
    new_content = re.sub(tags_pattern, fix_commas, new_content, flags=re.DOTALL)
    
    # Fix column_terms block
    terms_pattern = r'(column_terms\s*\()(.*?)(\n\s*\))'
    new_content = re.sub(terms_pattern, fix_commas, new_content, flags=re.DOTALL)
    
    if new_content != content:
        sql_file.write_text(new_content)
        return True
    
    return False

def main():
    print("=" * 80)
    print("SGWS Web Analytics - Fix Missing Commas in ALL Models")
    print("=" * 80)
    print()
    
    layers = ['bronze', 'silver', 'gold']
    total_fixed = 0
    total_files = 0
    
    for layer in layers:
        layer_dir = MODELS_DIR / layer
        if not layer_dir.exists():
            continue
        
        print(f"\n{layer.upper()} LAYER")
        print("-" * 80)
        
        sql_files = sorted(layer_dir.rglob('*.sql'))
        
        for sql_file in sql_files:
            total_files += 1
            if fix_column_descriptions(sql_file):
                print(f"  ✅ Fixed: {sql_file.relative_to(MODELS_DIR)}")
                total_fixed += 1
    
    print("\n" + "=" * 80)
    print(f"✅ Complete! Fixed: {total_fixed}/{total_files} files")
    print("=" * 80)
    print("\nVerify with: vulcan info")

if __name__ == "__main__":
    main()
