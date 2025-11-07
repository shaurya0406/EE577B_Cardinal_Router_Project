#!/usr/bin/env python3
#!/usr/bin/env python3
"""
merge_helix_rtl.py
Merge HELIX RTL into a single ordered design file for SITE_0.

Features
- Reads a zip (--zip /path/to/HELIX_RTL.zip) or an unpacked tree (--rtl /path/to/rtl).
- Finds the rtl/ tree, locates site/SITE_0.sv, and builds a dependency graph.
- Order: packages (HelixPkg.sv first) -> headers (.svh, Types.svh first) -> topo-sorted .sv (reachable from SITE_0).
- Strips all `include "..."` lines since files are inlined by order.
- Excludes testbenches (*_tb.sv), .xlsx/.txt/.c assets, etc.

Usage
  python3 merge_helix_rtl.py --zip /mnt/data/HELIX_RTL.zip --out merged_SITE_0.sv
  # or if you already have the repo unpacked:
  python3 merge_helix_rtl.py --rtl ./HELIX_RTL/rtl --out merged_SITE_0.sv
"""

import argparse
import io
import os
import re
import shutil
import sys
import tempfile
import textwrap
import zipfile
from collections import defaultdict, deque
from pathlib import Path


# ------------------------- CLI -------------------------

def parse_args():
    ap = argparse.ArgumentParser(description="Merge HELIX RTL into one file (SITE_0).")
    src = ap.add_mutually_exclusive_group(required=True)
    src.add_argument("--zip", type=Path, help="Path to HELIX_RTL.zip")
    src.add_argument("--rtl", type=Path, help="Path to rtl/ directory (unpacked)")
    ap.add_argument("--top-file", type=str, default="site/SITE_0.sv",
                    help="Top file path relative to rtl/ (default: site/SITE_0.sv)")
    ap.add_argument("--out", type=Path, default=Path("merged_SITE_0.sv"),
                    help="Output merged .sv file (default: merged_SITE_0.sv)")
    return ap.parse_args()


# ------------------------- Helpers -------------------------

TB_MARKERS = ("_tb.sv", "tb_.sv", "tb.sv")
MODULE_DEF_RE = re.compile(r'^\s*module\s+([a-zA-Z_]\w*)\b', re.M)
PACKAGE_DEF_RE = re.compile(r'^\s*package\s+([a-zA-Z_]\w*)\b', re.M)
INCLUDE_RE = re.compile(r'^\s*`include\s+"([^"]+)"\s*;?\s*$', re.M)

def is_sv_file(p: Path) -> bool:
    if p.suffix.lower() not in (".sv", ".svh"):
        return False
    name = p.name
    if any(name.endswith(m) for m in TB_MARKERS):
        return False
    # Ignore common non-RTL artifacts
    if name.lower().endswith((".xlsx", ".txt", ".c")):
        return False
    return True

def strip_includes(text: str) -> str:
    return INCLUDE_RE.sub("", text)

def read_clean(p: Path) -> str:
    try:
        txt = p.read_text(errors="ignore")
    except Exception:
        txt = p.read_bytes().decode("utf-8", errors="ignore")
    return strip_includes(txt).rstrip() + "\n\n"

def svh_sort_key(p: Path):
    # Highest priority: Types.svh (case-insensitive)
    if p.name.lower() == "types.svh":
        return (0, p.as_posix())
    # Prefer cordic/incl headers next (often typedefs / interfaces)
    in_cordic_incl = "cordic" in p.as_posix().lower() and "incl" in p.as_posix().lower()
    return (1 if in_cordic_incl else 2, p.as_posix())


# ------------------------- Core logic -------------------------

def find_rtl_root_from_zip(zip_path: Path) -> Path:
    assert zip_path.exists(), f"Zip not found: {zip_path}"
    tmpdir = Path(tempfile.mkdtemp(prefix="helix_rtl_"))
    extract_dir = tmpdir / "extract"
    extract_dir.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(zip_path, 'r') as zf:
        zf.extractall(extract_dir)
    rtl_dirs = [p for p in extract_dir.rglob("rtl") if p.is_dir()]
    if not rtl_dirs:
        raise RuntimeError("No 'rtl' directory found inside the zip. Check archive structure.")
    # pick the shallowest path
    rtl_root = min(rtl_dirs, key=lambda p: len(p.as_posix()))
    return rtl_root

def find_rtl_root_from_dir(rtl_path: Path) -> Path:
    if not rtl_path.exists() or not rtl_path.is_dir():
        raise RuntimeError(f"rtl path not found or not a directory: {rtl_path}")
    return rtl_path

def scan_files(rtl_root: Path):
    all_files = sorted([p for p in rtl_root.rglob("*") if p.is_file() and is_sv_file(p)])
    svh_files = [p for p in all_files if p.suffix.lower() == ".svh"]
    sv_files  = [p for p in all_files if p.suffix.lower() == ".sv"]
    return sv_files, svh_files

def build_module_db(sv_files):
    modules_by_file = {}
    files_by_module = {}
    packages = set()
    for f in sv_files:
        text = f.read_text(errors="ignore")
        for pkg in PACKAGE_DEF_RE.findall(text):
            packages.add(pkg)
        for m in MODULE_DEF_RE.findall(text):
            modules_by_file.setdefault(f, []).append(m)
            files_by_module[m] = f
    return modules_by_file, files_by_module, packages

def find_instantiated_modules(text: str, known: set):
    # Basic comment stripping
    text_nc = re.sub(r'//.*', '', text)
    text_nc = re.sub(r'/\*.*?\*/', '', text_nc, flags=re.S)
    instantiated = set()
    # Cheap prefilter to avoid huge regex on every module
    for m in known:
        if m not in text_nc:
            continue
        # Looks like: M #( ... ) inst(... ; or M inst ( ...
        if re.search(rf'(?<!\w){re.escape(m)}\s*(?:#\s*\(|\s+[A-Za-z_]\w*\s*\()', text_nc):
            instantiated.add(m)
    return instantiated

def build_dependency_graph(sv_files, files_by_module):
    graph = defaultdict(set)     # child_file -> {parent_files that instantiate it}
    rev_graph = defaultdict(set) # parent_file -> {child_files it uses}
    all_module_names = set(files_by_module.keys())

    for f in sv_files:
        text = f.read_text(errors="ignore")
        inst = find_instantiated_modules(text, all_module_names)
        for child_mod in inst:
            child_file = files_by_module.get(child_mod)
            if child_file and child_file != f:
                graph[child_file].add(f)
                rev_graph[f].add(child_file)
    return graph, rev_graph

def locate_site0_file(rtl_root: Path, sv_files, top_rel: str):
    # Try direct path first
    candidate = (rtl_root / top_rel)
    if candidate.exists():
        return candidate
    # Try common variants
    site0_candidates = [p for p in sv_files if p.name.lower() == "site_0.sv"]
    if site0_candidates:
        return site0_candidates[0]
    # Fallback: search for "module SITE_0"
    for f in sv_files:
        if re.search(r'\bmodule\s+SITE_0\b', f.read_text(errors="ignore")):
            return f
    raise RuntimeError("Could not locate SITE_0.sv in rtl tree.")

def reachable_files_from_top(site0: Path, rev_graph):
    needed = set()
    q = deque([site0])
    while q:
        cur = q.popleft()
        if cur in needed:
            continue
        needed.add(cur)
        for child in rev_graph.get(cur, set()):
            if child not in needed:
                q.append(child)
    return needed

def topo_sort_needed(needed_files, rev_graph):
    # Build in-deg within subgraph
    in_deg = {}
    children_map = defaultdict(set)
    for f in needed_files:
        parents = rev_graph.get(f, set()) & needed_files
        for p in parents:
            children_map[p].add(f)
        in_deg[f] = len(parents)
    # Kahn
    queue = deque(sorted([f for f,d in in_deg.items() if d == 0], key=lambda p: p.as_posix()))
    topo = []
    while queue:
        u = queue.popleft()
        topo.append(u)
        for v in sorted(children_map.get(u, set()), key=lambda p: p.as_posix()):
            in_deg[v] -= 1
            if in_deg[v] == 0:
                queue.append(v)
    if len(topo) != len(needed_files):
        # Cycle or heuristic miss: fall back to deterministic path sort
        topo = sorted(needed_files, key=lambda p: p.as_posix())
    return topo

def choose_pkg_files(sv_files, rtl_root: Path):
    # Any file under .../rtl/**/pkg/**.sv
    pkg_files = []
    for p in sv_files:
        parts = [x.lower() for x in p.relative_to(rtl_root).parts]
        if "pkg" in parts:
            pkg_files.append(p)
    # HelixPkg.sv first
    pkg_files_sorted = sorted(pkg_files, key=lambda p: (0 if p.name.lower() == "helixpkg.sv" else 1, p.as_posix()))
    return pkg_files_sorted

def merge_files(rtl_root: Path, pkg_files, svh_files_sorted, topo_sorted_sv, out_path: Path):
    banner = textwrap.dedent("""\
// =============================================================
// HELIX RTL \u2014 Single-File Merge for SITE_0
// Generated by merge_helix_rtl.py
// Order: pkg -> headers (.svh) -> reachable modules (topologically sorted) -> SITE_0
// Notes:
//  * All `include directives have been removed (files are inlined by order).
//  * Testbench files were excluded.
//  * This file is auto-generated; do not edit by hand.
// =============================================================
`timescale 1ns/1ps

""")
    parts = [banner]
    seen = set()

    def append_file(p: Path):
        parts.append(f"// ===== Begin {p.relative_to(rtl_root)} =====\n")
        parts.append(read_clean(p))
        parts.append(f"// ===== End {p.relative_to(rtl_root)} =====\n\n")
        seen.add(p)

    for p in pkg_files:
        if p.exists() and p not in seen:
            append_file(p)

    for p in svh_files_sorted:
        if p.exists() and p not in seen:
            append_file(p)

    for p in topo_sorted_sv:
        if p.exists() and p not in seen:
            append_file(p)

    merged = "".join(parts)
    out_path.write_text(merged)

    # Summary to stdout
    print("Merged HELIX RTL for SITE_0")
    print(f"RTL root: {rtl_root}")
    print(f"Output:   {out_path}")
    print(f"Headers (.svh) included: {len(svh_files_sorted)}")
    print(f"Files merged: {len(seen)}")
    print("Done.")


# ------------------------- Main -------------------------

def main():
    args = parse_args()

    if args.zip:
        rtl_root = find_rtl_root_from_zip(args.zip)
        # Keep temp dir alive until process exit; no cleanup here
    else:
        rtl_root = find_rtl_root_from_dir(args.rtl)

    sv_files, svh_files = scan_files(rtl_root)
    if not sv_files and not svh_files:
        raise RuntimeError("No SystemVerilog files found under rtl/")

    # Headers: Types.svh first, then the rest (cordic/incl prioritized)
    svh_files_sorted = sorted(svh_files, key=svh_sort_key)

    modules_by_file, files_by_module, _packages = build_module_db(sv_files)
    graph, rev_graph = build_dependency_graph(sv_files, files_by_module)

    site0 = locate_site0_file(rtl_root, sv_files, args.top_file)
    needed_files = reachable_files_from_top(site0, rev_graph)
    topo_sorted_sv = topo_sort_needed(needed_files, rev_graph)

    pkg_files = choose_pkg_files(sv_files, rtl_root)

    # Emit
    args.out.parent.mkdir(parents=True, exist_ok=True)
    merge_files(rtl_root, pkg_files, svh_files_sorted, topo_sorted_sv, args.out)


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"[merge_helix_rtl] ERROR: {e}", file=sys.stderr)
        sys.exit(1)