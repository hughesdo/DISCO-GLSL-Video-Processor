#!/usr/bin/env python3
"""
Check for missing shader files - find shaders in JSON but no .glsl file
"""

import json
from pathlib import Path

def check_missing_shaders():
    """Check which shaders are in JSON but missing .glsl files"""
    
    # Load shader configuration
    config_file = Path("Shaders/shader_config.json")
    if not config_file.exists():
        print("❌ shader_config.json not found!")
        return
    
    with open(config_file, 'r', encoding='utf-8') as f:
        shader_config = json.load(f)
    
    # Get list of actual .glsl files
    shaders_dir = Path("Shaders")
    actual_files = set()
    for glsl_file in shaders_dir.glob("*.glsl"):
        actual_files.add(glsl_file.name)
    
    # Check which JSON entries are missing files
    missing_files = []
    existing_files = []
    
    for shader_name in shader_config.keys():
        if shader_name in actual_files:
            existing_files.append(shader_name)
        else:
            missing_files.append(shader_name)
    
    # Check for .glsl files not in JSON
    orphaned_files = []
    for file_name in actual_files:
        if file_name not in shader_config:
            orphaned_files.append(file_name)
    
    # Print results
    print("🔍 SHADER FILE ANALYSIS")
    print("=" * 50)
    
    print(f"\n📊 SUMMARY:")
    print(f"   JSON entries: {len(shader_config)}")
    print(f"   Actual .glsl files: {len(actual_files)}")
    print(f"   Matching: {len(existing_files)}")
    print(f"   Missing files: {len(missing_files)}")
    print(f"   Orphaned files: {len(orphaned_files)}")
    
    if missing_files:
        print(f"\n❌ SHADERS IN JSON BUT MISSING .GLSL FILES:")
        for shader in sorted(missing_files):
            print(f"   - {shader}")
    else:
        print(f"\n✅ All JSON entries have corresponding .glsl files!")
    
    if orphaned_files:
        print(f"\n⚠️  .GLSL FILES NOT IN JSON CONFIG:")
        for shader in sorted(orphaned_files):
            print(f"   - {shader}")
    else:
        print(f"\n✅ All .glsl files are in JSON config!")
    
    if existing_files:
        print(f"\n✅ SHADERS WITH BOTH JSON AND .GLSL:")
        for shader in sorted(existing_files):
            print(f"   - {shader}")
    
    return missing_files, orphaned_files, existing_files

if __name__ == "__main__":
    missing, orphaned, existing = check_missing_shaders()
