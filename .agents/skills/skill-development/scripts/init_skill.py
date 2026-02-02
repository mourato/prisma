#!/usr/bin/env python3
"""
init_skill.py - Initialize a new Agent Skill structure

Usage:
    python scripts/init_skill.py <skill-name> [--path <output-directory>]

Example:
    python scripts/init_skill.py pdf-processor --path ./skills
    python scripts/init_skill.py my-skill --path ./plugins/my-plugin/skills
"""

import argparse
import os
import sys
from pathlib import Path


def create_skill_structure(skill_name: str, output_dir: Path) -> Path:
    """Create the skill directory structure with all necessary files."""
    
    skill_path = output_dir / skill_name
    skill_path.mkdir(parents=True, exist_ok=True)
    
    # Create directory structure
    directories = ["scripts", "references", "assets"]
    for directory in directories:
        (skill_path / directory).mkdir(exist_ok=True)
    
    # Create SKILL.md template
    skill_md = skill_path / "SKILL.md"
    skill_md.write_text(f"""---
name: {skill_name.replace('-', ' ').title().replace(' ', '')}
description: This skill should be used when the user asks to "specific action 1", "specific action 2", "specific action 3". Include exact trigger phrases users would say. Be concrete and specific about when to use this skill.
version: 0.1.0
---

# {skill_name.replace('-', ' ').title()}

This skill provides guidance and tools for {skill_name.replace('-', ' ')}.

## When to Use This Skill

Use this skill when:
- User asks to "specific trigger 1"
- User asks to "specific trigger 2"
- Task involves {skill_name.replace('-', ' ')} related operations

## Core Concepts

### Key Concept 1

Description of the first key concept.

### Key Concept 2

Description of the second key concept.

## Workflow

To accomplish tasks with this skill:

1. **Step 1**: First action to take
2. **Step 2**: Second action to take
3. **Step 3**: Third action to take

## Additional Resources

### Reference Files

For detailed information, consult:
- **`references/`** - Detailed documentation and patterns

### Scripts

Utility scripts available in `scripts/`:
- **`script-name.sh`** - Description of what the script does

## Examples

### Example 1

```bash
# Example command or code
```

### Example 2

```bash
# Another example
```

## Best Practices

- Practice 1
- Practice 2
- Practice 3

## Common Mistakes to Avoid

- Mistake 1
- Mistake 2
""")
    
    # Create example script
    example_script = skill_path / "scripts" / "example.sh"
    example_script.write_text("""#!/bin/bash
# Example script for the skill

echo "This is an example script"

# Add your script logic here
""")
    example_script.chmod(0o755)
    
    # Create example reference
    example_ref = skill_path / "references" / "patterns.md"
    example_ref.write_text("""# Patterns

## Pattern 1

Description of pattern 1 with examples.

## Pattern 2

Description of pattern 2 with examples.
""")
    
    # Create example asset placeholder
    example_asset = skill_path / "assets" / ".gitkeep"
    example_asset.write_text("")
    
    return skill_path


def main():
    parser = argparse.ArgumentParser(
        description="Initialize a new Agent Skill structure",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""Example:
  python scripts/init_skill.py pdf-processor --path ./skills
  python scripts/init_skill.py my-skill --path ./plugins/my-plugin/skills
"""
    )
    parser.add_argument(
        "skill_name",
        help="Name of the skill to create (e.g., 'pdf-processor')"
    )
    parser.add_argument(
        "--path",
        type=Path,
        default=Path("."),
        help="Output directory for the skill (default: current directory)"
    )
    
    args = parser.parse_args()
    
    # Validate skill name
    if not args.skill_name.replace("-", "").replace("_", "").isalnum():
        print(f"Error: Skill name '{args.skill_name}' contains invalid characters.")
        print("Use only alphanumeric characters, hyphens (-), and underscores (_).")
        sys.exit(1)
    
    # Create the skill structure
    try:
        skill_path = create_skill_structure(args.skill_name, args.path)
        print(f"✅ Skill '{args.skill_name}' created successfully at:")
        print(f"   {skill_path}")
        print()
        print("Next steps:")
        print(f"  1. Edit {skill_path / 'SKILL.md'} with your skill content")
        print(f"  2. Add scripts to {skill_path / 'scripts'}/")
        print(f"  3. Add references to {skill_path / 'references'}/")
        print(f"  4. Add assets to {skill_path / 'assets'}/")
    except Exception as e:
        print(f"Error creating skill: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
