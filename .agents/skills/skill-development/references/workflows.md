# Workflow Patterns

## Sequential Workflows

For complex tasks, break operations into clear, sequential steps. It is often helpful to give Claude an overview of the process towards the beginning of SKILL.md:

```markdown
Filling a PDF form involves these steps:

1. Analyze the form (run analyze_form.py)
2. Create field mapping (edit fields.json)
3. Validate mapping (run validate_fields.py)
4. Fill the form (run fill_form.py)
5. Verify output (run verify_output.py)
```

## Conditional Workflows

For tasks with branching logic, guide Claude through decision points:

```markdown
1. Determine the modification type:
   **Creating new content?** → Follow "Creation workflow" below
   **Editing existing content?** → Follow "Editing workflow" below

2. Creation workflow: [steps]
3. Editing workflow: [steps]
```

## Multi-Step Process Pattern

For complex workflows with multiple stages, structure the guidance progressively:

```markdown
## Processing Pipeline

The skill processes data through these stages:

1. **Extraction** → See [references/extraction.md](extraction.md)
2. **Transformation** → See [references/transformation.md](transformation.md)
3. **Validation** → See [references/validation.md](validation.md)
4. **Export** → See [references/export.md](export.md)

Each stage has its own reference file with detailed patterns.
```

## Decision Tree Pattern

When Claude needs to make decisions based on conditions:

```markdown
## Path Selection

Choose the appropriate path based on input characteristics:

| Input Type | Path | Reference |
|------------|------|-----------|
| JSON data | Parse with schema validation | [references/json.md](json.md) |
| XML data | Parse with XPath extraction | [references/xml.md](xml.md) |
| CSV data | Parse with type inference | [references/csv.md](csv.md) |
| Plain text | Extract with regex patterns | [references/text.md](text.md) |
```
