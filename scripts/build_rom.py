import os
import sys
import platform
import argparse
import subprocess


def detect_platform():
    """Auto-detect host OS/arch and return matching bin/ subfolder.
    Mirrors the logic from Makefile.
    """
    system = platform.system()
    machine = platform.machine()

    if system == "Windows":
        return "windows_i386"
    elif system == "Darwin":
        return f"macos_{machine}"
    else:
        # Linux and other POSIX
        return f"linux_{machine}"


def get_default_tools():
    """Return default (as_bin, p2bin) paths based on detected platform."""
    plat = detect_platform()
    system = platform.system()

    if system == "Windows":
        as_exe = "asw.exe"
        p2bin_exe = "p2bin.exe"
    else:
        # Linux / macOS: no .exe, and AS is called 'asl'
        as_exe = "asl"
        p2bin_exe = "p2bin"

    as_bin = os.path.join("bin", plat, as_exe)
    p2bin = os.path.join("bin", plat, p2bin_exe)
    return as_bin, p2bin


def run_process(cmd):
    """Execute shell command and wait for completion"""
    p = subprocess.Popen(cmd, bufsize=2048, shell=True)
    return p.wait()


def assemble_main_src(base_dir, src_file, output_file, as_bin, p2bin, as_args):
    """Assemble source file and convert to binary ROM"""
    # Get absolute paths before changing directory
    src_abs = os.path.abspath(src_file)
    output_abs = os.path.abspath(output_file)
    p2bin_abs = os.path.abspath(p2bin)
    as_bin_abs = os.path.abspath(as_bin)

    # Get bin directory
    bin_dir = os.path.dirname(as_bin_abs)

    # Calculate relative path from bin to source
    src_rel = os.path.relpath(src_abs, os.getcwd())

    # Use full path to assembler
    asm_cmd = f'"{as_bin_abs}" {as_args} "{src_rel}"'
    print(f'Assembling: {asm_cmd}')
    ret = run_process(asm_cmd)

    if ret != 0:
        print(f'Assembly failed with code {ret}')
        return ret

    # Convert .p file to binary
    pre, ext = os.path.splitext(src_abs)
    p_file_abs = pre + '.p'

    if not os.path.exists(p_file_abs):
        print(f'Error: Object file {p_file_abs} not found')
        return 1

    p2bin_cmd = f'"{p2bin_abs}" "{p_file_abs}" "{output_abs}"'
    print(f'Converting to binary: {p2bin_cmd}')
    ret = run_process(p2bin_cmd)
    if ret != 0:
        print(f'Conversion failed with code {ret}')
        return ret

    print(f'Build complete: {output_file}')
    return 0


if __name__ == '__main__':
    default_as_bin, default_p2bin = get_default_tools()

    parser = argparse.ArgumentParser(
        description='Build Alien Soldier ROM from assembly source'
    )
    parser.add_argument('-s', '--source', default='alien_soldier_j.s',
                        help='Source assembly file (default: alien_soldier_j.s)')
    parser.add_argument('-o', '--output', default='asbuilt.bin',
                        help='Output ROM file (default: asbuilt.bin)')
    parser.add_argument('--as-bin', default=default_as_bin,
                        help=f'Path to AS assembler (default: {default_as_bin})')
    parser.add_argument('--p2bin', default=default_p2bin,
                        help=f'Path to p2bin converter (default: {default_p2bin})')
    parser.add_argument('--as-args', default='-maxerrors 2',
                        help='Arguments for AS assembler (default: -maxerrors 2)')
    args = parser.parse_args()

    basedir = os.getcwd()

    ret = assemble_main_src(
        basedir,
        args.source,
        args.output,
        args.as_bin,
        args.p2bin,
        args.as_args
    )

    sys.exit(ret)