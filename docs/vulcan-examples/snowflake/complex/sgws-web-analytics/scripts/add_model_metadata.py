#!/usr/bin/env python3
"""
Add comprehensive metadata to all SGWS Web Analytics models
"""

import re
from pathlib import Path
from typing import Dict, List, Tuple

# Configuration
MODELS_DIR = Path(__file__).parent / "models"
OWNER = "rohitrajtmdcio"

# Metadata templates by layer
LAYER_METADATA = {
    'gold': {
        'tags_base': ('gold', 'analytics_ready', 'business_layer'),
        'terms_prefix': 'sgws',
    },
    'silver': {
        'tags_base': ('silver', 'transformed', 'cleaned'),
        'terms_prefix': 'transformation',
    },
    'bronze_redshift': {
        'tags_base': ('bronze', 'raw', 'redshift', 'ingestion'),
        'terms_prefix': 'raw.redshift',
    },
    'bronze_adobe': {
        'tags_base': ('bronze', 'raw', 'adobe_analytics', 'ingestion'),
        'terms_prefix': 'raw.adobe',
    },
}

# Common column patterns and their metadata
COLUMN_PATTERNS = {
    '_pk$|_sk$': {
        'tag': ('identifier', 'primary_key'),
        'desc_suffix': 'unique identifier'
    },
    '_no$|_id$': {
        'tag': ('identifier', 'foreign_key'),
        'desc_suffix': 'identifier'
    },
    'customer': {
        'tag': ('customer', 'dimension'),
        'desc_suffix': 'customer-related field'
    },
    'site': {
        'tag': ('location', 'dimension'),
        'desc_suffix': 'site/location field'
    },
    'item|product': {
        'tag': ('product', 'dimension'),
        'desc_suffix': 'product/item field'
    },
    '_date|_dt$': {
        'tag': ('temporal', 'date'),
        'desc_suffix': 'date field'
    },
    'amt$|revenue|price|cost': {
        'tag': ('metric', 'currency'),
        'desc_suffix': 'monetary amount'
    },
    'qty|quantity|cases|bottles': {
        'tag': ('metric', 'quantity'),
        'desc_suffix': 'quantity measurement'
    },
    'status|_cd$': {
        'tag': ('classification', 'status'),
        'desc_suffix': 'status/classification code'
    },
    '_flg$|_ind$': {
        'tag': ('flag', 'boolean'),
        'desc_suffix': 'boolean flag'
    },
}

def extract_model_name(content: str) -> str:
    """Extract model name from MODEL definition"""
    match = re.search(r'name\s+(\w+\.\w+)', content)
    return match.group(1) if match else 'unknown'

def extract_select_columns(content: str) -> List[str]:
    """Extract column names from final SELECT statement"""
    # Find the final SELECT statement
    select_match = re.search(r'(?:^|\n)SELECT\s+(.*?)\s+FROM', content, re.DOTALL | re.IGNORECASE)
    if not select_match:
        return []
    
    select_clause = select_match.group(1)
    columns = []
    
    # Parse columns (simple extraction)
    for line in select_clause.split('\n'):
        line = line.strip()
        if line.startswith('--') or not line:
            continue
        
        # Extract column name (handle AS aliases)
        if ' AS ' in line.upper():
            match = re.search(r'\s+AS\s+(\w+)', line, re.IGNORECASE)
            if match:
                columns.append(match.group(1).upper())
        else:
            # Direct column reference
            match = re.search(r'(\w+)[,\s]*$', line)
            if match:
                columns.append(match.group(1).upper())
    
    return columns

def infer_column_metadata(column_name: str) -> Tuple[str, str]:
    """Infer tag and description for a column based on naming patterns"""
    col_lower = column_name.lower()
    
    for pattern, metadata in COLUMN_PATTERNS.items():
        if re.search(pattern, col_lower):
            tag = metadata['tag'][0]
            desc = f"{column_name.replace('_', ' ').title()} - {metadata['desc_suffix']}"
            return tag, desc
    
    return 'attribute', f"{column_name.replace('_', ' ').title()}"

def generate_model_metadata(file_path: Path, layer: str) -> str:
    """Generate comprehensive metadata block for a model"""
    
    content = file_path.read_text()
    model_name = extract_model_name(content)
    columns = extract_select_columns(content)
    
    # Determine model type
    if 'CUSTOMER' in model_name.upper():
        model_type = 'dimension'
        entity = 'customer'
        description = f'{layer.title()} layer customer data with demographics, site information, and sales classifications'
    elif 'PRODUCT' in model_name.upper() or 'ITEM' in model_name.upper():
        model_type = 'dimension'
        entity = 'product'
        description = f'{layer.title()} layer product catalog data with brand, classification, and supplier information'
    elif 'SALES' in model_name.upper():
        model_type = 'fact'
        entity = 'sales'
        description = f'{layer.title()} layer sales transaction fact table with revenue, quantities, and invoice details'
    elif 'ORDER' in model_name.upper():
        model_type = 'fact'
        entity = 'orders'
        description = f'{layer.title()} layer order transaction fact table with order status and fulfillment tracking'
    elif 'ADOBE' in model_name.upper() or 'WEB' in model_name.upper() or 'HIT' in model_name.upper():
        model_type = 'fact'
        entity = 'web_analytics'
        description = f'{layer.title()} layer Adobe Analytics clickstream data with enriched dimensions and user behavior tracking'
    else:
        model_type = 'dimension'
        entity = model_name.split('.')[-1].lower()
        description = f'{layer.title()} layer {entity} reference data'
    
    # Build tags
    layer_key = 'bronze_adobe' if 'adobe' in file_path.parts else 'bronze_redshift' if layer == 'bronze' else layer
    base_tags = LAYER_METADATA.get(layer_key, LAYER_METADATA['silver'])['tags_base']
    tags = base_tags + (model_type, entity)
    
    # Build terms
    terms_prefix = LAYER_METADATA.get(layer_key, LAYER_METADATA['silver'])['terms_prefix']
    terms = (f'{terms_prefix}.{entity}', f'{model_type}.{entity}')
    
    # Infer grain
    grain_candidates = [col for col in columns if '_pk' in col.lower() or '_sk' in col.lower() or '_id' in col.lower()]
    grain = grain_candidates[:1] if grain_candidates else []
    
    # Build column descriptions (top 15-20 columns)
    col_descriptions = []
    for col in columns[:20]:
        _, desc = infer_column_metadata(col)
        col_descriptions.append(f"    {col} = '{desc}'")
    
    # Build column tags (top 15-20 columns)
    col_tags = []
    for col in columns[:20]:
        tag, _ = infer_column_metadata(col)
        col_tags.append(f"    {col} = ('{tag}', '{model_type}')")
    
    # Build metadata block
    metadata = f"""MODEL (
  name {model_name},
  kind FULL,
  owner '{OWNER}',"""
    
    if grain:
        metadata += f"\n  grains [{', '.join(grain)}],"
    
    metadata += f"""
  description '{description}',
  tags {tags},
  terms {terms}"""
    
    if col_descriptions:
        metadata += f""",
  
  -- ==================== COLUMN DESCRIPTIONS ====================
  column_descriptions (
{chr(10).join(col_descriptions[:15])}
  )"""
    
    if col_tags:
        metadata += f""",
  
  -- ==================== COLUMN TAGS ====================
  column_tags (
{chr(10).join(col_tags[:15])}
  )"""
    
    metadata += "\n);"
    
    return metadata

def update_model_file(file_path: Path, layer: str):
    """Update a model file with comprehensive metadata"""
    
    print(f"Processing: {file_path.relative_to(MODELS_DIR)}")
    
    content = file_path.read_text()
    
    # Skip seed models for now (special handling needed)
    if '/seeds/' in str(file_path):
        print(f"  ⏭️  Skipping seed model (requires special handling)")
        return
    
    # Find existing MODEL block
    model_match = re.search(r'MODEL\s*\((.*?)\);', content, re.DOTALL)
    if not model_match:
        print(f"  ❌ No MODEL block found")
        return
    
    # Check if already has owner
    if 'owner' in model_match.group(1):
        print(f"  ✅ Already has metadata")
        return
    
    # Generate new metadata
    new_metadata = generate_model_metadata(file_path, layer)
    
    # Replace MODEL block
    new_content = content.replace(model_match.group(0), new_metadata)
    
    # Write back
    file_path.write_text(new_content)
    print(f"  ✅ Updated with metadata")

def main():
    print("=" * 80)
    print("SGWS Web Analytics - Metadata Enhancement")
    print("=" * 80)
    print()
    
    # Process models by layer
    layers = [
        ('gold', MODELS_DIR / 'gold'),
        ('silver', MODELS_DIR / 'silver'),
        ('bronze', MODELS_DIR / 'bronze'),
    ]
    
    total_updated = 0
    
    for layer_name, layer_dir in layers:
        if not layer_dir.exists():
            continue
        
        print(f"\n{layer_name.upper()} LAYER")
        print("-" * 80)
        
        sql_files = list(layer_dir.rglob('*.sql'))
        for sql_file in sorted(sql_files):
            if sql_file.name != '.sql':
                update_model_file(sql_file, layer_name)
                total_updated += 1
    
    print()
    print("=" * 80)
    print(f"✅ Metadata Enhancement Complete!")
    print(f"   Processed {total_updated} model files")
    print("=" * 80)
    print()
    print("Next: Run 'vulcan info' to validate metadata")

if __name__ == "__main__":
    main()
