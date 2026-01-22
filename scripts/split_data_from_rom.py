#!/usr/bin/env python3
"""
Extract binary data segments from ROM into organized subdirectories.

Reads data_addrs.txt with format:
    name,start,end,subdir
    tiles_0ED4B4,0xED4B4,0xED7A4,artcomp

Creates data/{subdir}/{name}.bin for each entry.
"""

import os
import sys
import argparse


def main():
    parser = argparse.ArgumentParser(description='Extract binary data from ROM')
    parser.add_argument('-f', '--rom-file', required=True,
                        help='Original ROM file')
    parser.add_argument('-o', '--output', default='data',
                        help='Output directory (default: data)')
    parser.add_argument('-a', '--addrs', default='data/data_addrs.txt',
                        help='Addresses file (default: data/data_addrs.txt)')

    args = parser.parse_args()

    # Check if ROM file exists
    if not os.path.exists(args.rom_file):
        print(f'Error: ROM file "{args.rom_file}" not found!')
        return 1

    # Check if addresses file exists
    if not os.path.exists(args.addrs):
        print(f'Error: Addresses file "{args.addrs}" not found!')
        return 1

    # Load ROM data
    print(f'Loading ROM: {args.rom_file}')
    with open(args.rom_file, 'rb') as f:
        rom_data = f.read()
    print(f'ROM size: 0x{len(rom_data):X} ({len(rom_data)} bytes)')

    # Parse addresses file
    print(f'Loading addresses from: {args.addrs}')
    entries = []
    with open(args.addrs, 'r') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            parts = line.split(',')
            if len(parts) < 3:
                print(f'Warning: invalid line: {line}')
                continue

            name = parts[0].strip()
            start = int(parts[1].strip(), 16)
            end = int(parts[2].strip(), 16)
            # 4th column is subdir, default to root if not present
            subdir = parts[3].strip() if len(parts) >= 4 else ''
            entries.append((name, start, end, subdir))

    print(f'Found {len(entries)} entries to extract\n')

    # Create subdirectories
    subdirs = set(e[3] for e in entries if e[3])
    for subdir in subdirs:
        os.makedirs(os.path.join(args.output, subdir), exist_ok=True)

    # Extract all segments
    success_count = 0
    counts_by_subdir = {}

    for name, start, end, subdir in entries:
        size = end - start

        if subdir:
            output_file = os.path.join(args.output, subdir, f'{name}.bin')
        else:
            output_file = os.path.join(args.output, f'{name}.bin')

        if start >= len(rom_data) or end > len(rom_data):
            print(f'Error: {name} address out of range (0x{start:X}-0x{end:X})')
            continue

        data = rom_data[start:end]
        with open(output_file, 'wb') as f:
            f.write(data)

        counts_by_subdir[subdir or 'root'] = counts_by_subdir.get(subdir or 'root', 0) + 1
        success_count += 1

    # Summary
    print(f'Extracted {success_count}/{len(entries)} segments:')
    for subdir in sorted(counts_by_subdir.keys()):
        count = counts_by_subdir[subdir]
        path = f'{args.output}/{subdir}/' if subdir != 'root' else f'{args.output}/'
        print(f'  {path}: {count} files')

    return 0 if success_count == len(entries) else 1


if __name__ == '__main__':
    sys.exit(main())
