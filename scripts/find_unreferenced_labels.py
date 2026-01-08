#!/usr/bin/env python3
"""
Find Unreferenced Labels in Alien Soldier Disassembly

Analyzes the disassembly to find ALL labels that are defined but never
referenced in actual code (comments are ignored).

A label is unreferenced if it only appears in its definition line and
nowhere else in the actual code.

Usage:
    python scripts/find_unreferenced_labels.py
    python scripts/find_unreferenced_labels.py --output unreferenced.txt
"""

import re
import argparse
from collections import defaultdict


def strip_comment(line: str) -> str:
    """Remove comment portion from a line (everything after first ;)."""
    pos = line.find(';')
    if pos >= 0:
        return line[:pos]
    return line


def classify_label(label_name: str) -> str:
    """Classify a label by its naming pattern."""
    if label_name.startswith('sub_'):
        return 'sub'
    elif label_name.startswith('loc_'):
        return 'loc'
    elif label_name.startswith('locret_'):
        return 'locret'
    elif label_name.startswith('byte_'):
        return 'byte'
    elif label_name.startswith('word_'):
        return 'word'
    elif label_name.startswith('dword_'):
        return 'dword'
    elif label_name.startswith('off_'):
        return 'off'
    elif label_name.startswith('unk_'):
        return 'unk'
    elif label_name.startswith('stru_'):
        return 'stru'
    elif label_name.startswith('nullsub_'):
        return 'nullsub'
    else:
        return 'custom'


def find_unreferenced_labels(source_file: str) -> list:
    """
    Find ALL labels that are defined but never referenced in code.

    Args:
        source_file: Path to assembly source file

    Returns:
        List of (label_name, line_number, label_type) tuples
    """
    # Read source file
    with open(source_file, 'r', encoding='utf-8', errors='ignore') as f:
        lines = f.readlines()

    print(f"Loaded {len(lines):,} lines from {source_file}")

    # Pattern to match ANY label definition at start of line
    # Label: word characters (letters, digits, underscore) starting with letter or underscore
    definition_pattern = re.compile(r'^([a-zA-Z_][a-zA-Z0-9_]*):')

    # Pass 1: Find all label definitions
    print("Pass 1: Finding ALL label definitions...")
    labels = {}  # label_name -> (line_number, label_type)

    for line_num, line in enumerate(lines, start=1):
        match = definition_pattern.match(line)
        if match:
            label_name = match.group(1)
            label_type = classify_label(label_name)
            labels[label_name] = (line_num, label_type)

    print(f"Found {len(labels):,} label definitions")

    if not labels:
        return []

    # Pass 2: Count references to each label (excluding comments)
    print("Pass 2: Counting references (ignoring comments)...")
    reference_counts = defaultdict(int)
    label_names_set = set(labels.keys())

    # Build a single regex that matches any of our labels as whole words
    # For efficiency, we'll search for potential identifiers and check against our set
    identifier_pattern = re.compile(r'\b([a-zA-Z_][a-zA-Z0-9_]*)\b')

    for line in lines:
        # Strip comment portion - this is the key fix!
        code_part = strip_comment(line)

        # Skip if no code left
        if not code_part.strip():
            continue

        # Find all identifiers in code part
        matches = identifier_pattern.findall(code_part)
        for identifier in matches:
            if identifier in label_names_set:
                reference_counts[identifier] += 1

    # Pass 3: Find unreferenced labels
    # A label is unreferenced if it appears exactly once (only in its definition)
    print("Pass 3: Identifying unreferenced labels...")
    unreferenced = []

    for label_name, (line_num, label_type) in labels.items():
        # Skip _End labels (linker markers for end of binary includes)
        if label_name.endswith('_End'):
            continue

        count = reference_counts.get(label_name, 0)
        # count == 1 means only the definition line has this label
        if count <= 1:
            unreferenced.append((label_name, line_num, label_type))

    # Sort by line number
    unreferenced.sort(key=lambda x: x[1])

    return unreferenced


def main():
    parser = argparse.ArgumentParser(
        description='Find ALL unreferenced labels in Alien Soldier disassembly'
    )
    parser.add_argument(
        'input',
        nargs='?',
        default='alien_soldier_j.s',
        help='Input disassembly file (default: alien_soldier_j.s)'
    )
    parser.add_argument(
        '--output',
        help='Output file for results'
    )

    args = parser.parse_args()

    print("=" * 70)
    print("UNREFERENCED LABELS FINDER (ALL LABELS)")
    print("=" * 70)

    # Find unreferenced labels
    unreferenced = find_unreferenced_labels(args.input)

    print(f"\nFound {len(unreferenced)} unreferenced labels")
    print("=" * 70)

    if not unreferenced:
        print("No unreferenced labels found!")
        return 0

    # Group by type for display
    by_type = defaultdict(list)
    for label_name, line_num, label_type in unreferenced:
        by_type[label_type].append((label_name, line_num))

    # Output
    output_lines = []
    output_lines.append("=" * 70)
    output_lines.append(f"UNREFERENCED LABELS: {len(unreferenced)} total")
    output_lines.append("=" * 70)

    # Sort types: custom first, then alphabetically
    type_order = ['custom'] + sorted([t for t in by_type.keys() if t != 'custom'])

    for label_type in type_order:
        if label_type not in by_type:
            continue
        labels_of_type = by_type[label_type]
        output_lines.append(f"\n{label_type.upper()} ({len(labels_of_type)}):")
        output_lines.append("-" * 40)
        for label_name, line_num in labels_of_type:
            output_lines.append(f"  {label_name:40s} (line {line_num})")

    output_text = '\n'.join(output_lines)
    print(output_text)

    # Save to file if requested
    if args.output:
        with open(args.output, 'w', encoding='utf-8') as f:
            f.write(output_text)
        print(f"\nResults saved to {args.output}")

    return 0


if __name__ == '__main__':
    exit(main())
