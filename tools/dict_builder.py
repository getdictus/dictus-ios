#!/usr/bin/env python3
"""
dict_builder.py -- Build compressed patricia trie binary dictionaries for Dictus.

Reads a frequency JSON file ({"word": count, ...}) and generates a binary .dict
file with the DTRI format: 32-byte header + depth-first pre-order patricia trie nodes.

Usage:
    python3 tools/dict_builder.py INPUT.json OUTPUT.dict

The binary format is designed for mmap-based read-only access from C++ on iOS,
with no dynamic allocation needed for traversal.
"""

import json
import math
import struct
import sys
from dataclasses import dataclass, field
from typing import Optional


# --- Constants ---
MAGIC = b"DTRI"
VERSION = 1
HEADER_SIZE = 32


# --- Patricia Trie (in-memory build structure) ---
@dataclass
class TrieNode:
    """In-memory trie node for building."""
    chars: list[int] = field(default_factory=list)  # UTF-16 code units
    children: dict[int, "TrieNode"] = field(default_factory=dict)  # first char -> child
    is_terminal: bool = False
    frequency: int = 0  # raw frequency from JSON

    def child_list(self) -> list["TrieNode"]:
        """Children sorted by first character for deterministic output."""
        return [self.children[k] for k in sorted(self.children.keys())]


def insert_word(root: TrieNode, word: str, freq: int) -> None:
    """Insert a word into the patricia trie."""
    # Convert to UTF-16 code units
    code_units = [ord(c) for c in word]
    _insert(root, code_units, freq)


def _insert(node: TrieNode, remaining: list[int], freq: int) -> None:
    if not remaining:
        node.is_terminal = True
        node.frequency = max(node.frequency, freq)
        return

    first = remaining[0]
    if first in node.children:
        child = node.children[first]
        # Find common prefix length between child.chars and remaining
        common = 0
        while common < len(child.chars) and common < len(remaining) and child.chars[common] == remaining[common]:
            common += 1

        if common == len(child.chars):
            # Full match of child chars -- recurse into child
            _insert(child, remaining[common:], freq)
        else:
            # Partial match -- split child
            # Create new intermediate node with the common prefix
            split = TrieNode(chars=child.chars[:common])
            # Old child becomes suffix after split point
            child.chars = child.chars[common:]
            split.children[child.chars[0]] = child
            # Replace in parent
            node.children[first] = split

            if common == len(remaining):
                split.is_terminal = True
                split.frequency = max(split.frequency, freq)
            else:
                # Create new leaf for the remainder
                new_leaf = TrieNode(chars=remaining[common:], is_terminal=True, frequency=freq)
                split.children[remaining[common]] = new_leaf
    else:
        # No matching child -- create new leaf
        node.children[first] = TrieNode(chars=remaining, is_terminal=True, frequency=freq)


def compress_trie(node: TrieNode) -> int:
    """Patricia compression: merge single-child non-terminal nodes.
    Returns total node count after compression."""
    count = 0 if not node.chars else 1  # root has no chars

    for key in list(node.children.keys()):
        child = node.children[key]
        # Recursively compress children first
        count += compress_trie(child)
        # Merge if this child has exactly one child and is not terminal
        while len(child.children) == 1 and not child.is_terminal:
            grandchild = list(child.children.values())[0]
            child.chars = child.chars + grandchild.chars
            child.children = grandchild.children
            child.is_terminal = grandchild.is_terminal
            child.frequency = grandchild.frequency
            count -= 1  # merged away one node

    return count


# --- Binary serialization ---
def serialize_trie(root: TrieNode, max_freq: int) -> tuple[bytes, int, int]:
    """Serialize trie to binary DTRI format.
    Returns (data_bytes, node_count, word_count)."""
    # Phase 1: Compute serialized size for each node to determine offsets
    # Phase 2: Write nodes in depth-first pre-order

    node_count = 0
    word_count = 0

    # We need two passes: first to assign offsets, then to write.
    # Collect all nodes in DFS pre-order, with their children info.
    nodes_order: list[tuple[TrieNode, int]] = []  # (node, placeholder for offset)

    def collect_dfs(node: TrieNode) -> None:
        nonlocal node_count, word_count
        if node.chars:  # skip root (has no chars)
            nodes_order.append((node, 0))
            node_count += 1
            if node.is_terminal:
                word_count += 1
        for child in node.child_list():
            collect_dfs(child)

    collect_dfs(root)

    # Now compute offsets. We need to know the size of each node to compute
    # absolute offsets for children_offset fields.
    # Size of a node:
    #   1 (flags) + [1 if multi_char] + N*2 (chars) + [2 if terminal] + [1+ptr_size if has children]

    def node_size(n: TrieNode, ptr_bytes: int) -> int:
        sz = 1  # flags
        if len(n.chars) > 1:
            sz += 1  # char_count
        sz += len(n.chars) * 2  # characters
        if n.is_terminal:
            sz += 2  # frequency
        if n.children:
            sz += 1 + ptr_bytes  # child_count + children_offset
        return sz

    # We need to iterate to find stable pointer sizes.
    # Start with 4-byte pointers, compute offsets, then shrink if possible.
    offsets = {}
    for attempt in range(3):
        offset = HEADER_SIZE
        for i, (node, _) in enumerate(nodes_order):
            offsets[id(node)] = offset
            # Determine ptr_bytes for this node
            if not node.children:
                ptr_bytes = 0
            else:
                # Use current estimate (4 bytes max for first pass)
                if attempt == 0:
                    ptr_bytes = 4
                else:
                    # Use actual offset of first child to determine ptr size
                    first_child = node.child_list()[0]
                    child_off = offsets.get(id(first_child), 0xFFFFFFFF)
                    if child_off <= 0xFFFF:
                        ptr_bytes = 2
                    elif child_off <= 0xFFFFFF:
                        ptr_bytes = 3
                    else:
                        ptr_bytes = 4
            offset += node_size(node, ptr_bytes)

    # Final write pass
    buf = bytearray()
    # Header
    buf.extend(MAGIC)
    buf.extend(struct.pack("<H", VERSION))
    buf.extend(struct.pack("<H", 0))  # flags
    buf.extend(struct.pack("<I", node_count))
    buf.extend(struct.pack("<I", word_count))
    # Cap max_freq to uint32 range for header storage (log normalization still uses real value)
    header_max_freq = min(max_freq, 0xFFFFFFFF)
    buf.extend(struct.pack("<I", header_max_freq))
    buf.extend(b"\x00" * 12)  # reserved
    assert len(buf) == HEADER_SIZE

    log_max = math.log(1 + max_freq) if max_freq > 0 else 1.0

    for node, _ in nodes_order:
        has_children = bool(node.children)
        multi_char = len(node.chars) > 1

        # Determine ptr_bytes
        if not has_children:
            ptr_bytes = 0
        else:
            first_child = node.child_list()[0]
            child_off = offsets[id(first_child)]
            if child_off <= 0xFFFF:
                ptr_bytes = 2
            elif child_off <= 0xFFFFFF:
                ptr_bytes = 3
            else:
                ptr_bytes = 4

        # Encode ptr_bytes into flag bits 7-6: 00=0, 01=2, 10=3, 11=4
        ptr_code = {0: 0, 2: 1, 3: 2, 4: 3}[ptr_bytes]

        flags = (ptr_code << 6)
        if multi_char:
            flags |= 0x20
        if node.is_terminal:
            flags |= 0x10

        buf.append(flags)

        if multi_char:
            buf.append(len(node.chars))

        for cu in node.chars:
            buf.extend(struct.pack("<H", cu))

        if node.is_terminal:
            # Log-normalized frequency to uint16
            norm = int(65535 * math.log(1 + node.frequency) / log_max) if node.frequency > 0 else 0
            norm = min(65535, max(0, norm))
            buf.extend(struct.pack("<H", norm))

        if has_children:
            child_count = len(node.children)
            buf.append(child_count)
            first_child = node.child_list()[0]
            child_off = offsets[id(first_child)]
            if ptr_bytes == 2:
                buf.extend(struct.pack("<H", child_off))
            elif ptr_bytes == 3:
                buf.extend(struct.pack("<I", child_off)[:3])
            elif ptr_bytes == 4:
                buf.extend(struct.pack("<I", child_off))

    return bytes(buf), node_count, word_count


def build_dict(input_path: str, output_path: str) -> None:
    """Build binary dictionary from frequency JSON."""
    print(f"Reading {input_path}...")
    with open(input_path, "r", encoding="utf-8") as f:
        freq_data: dict[str, int] = json.load(f)

    print(f"  Loaded {len(freq_data)} words")

    # Filter: lowercase, no spaces/hyphens, non-empty
    filtered = {}
    for word, count in freq_data.items():
        w = word.lower().strip()
        if not w or " " in w or "-" in w or count <= 0:
            continue
        filtered[w] = max(filtered.get(w, 0), count)

    print(f"  After filtering: {len(filtered)} words")

    max_freq = max(filtered.values()) if filtered else 1

    # Build patricia trie
    print("Building patricia trie...")
    root = TrieNode()
    for word, freq in filtered.items():
        insert_word(root, word, freq)

    # Compress
    print("Compressing (patricia merge)...")
    compress_trie(root)

    # Serialize
    print("Serializing binary format...")
    data, node_count, word_count = serialize_trie(root, max_freq)

    # Write
    with open(output_path, "wb") as f:
        f.write(data)

    size_kb = len(data) / 1024
    size_mb = size_kb / 1024
    print(f"\nStats:")
    print(f"  Words: {word_count}")
    print(f"  Nodes: {node_count}")
    print(f"  File size: {len(data)} bytes ({size_mb:.2f} MiB)")
    print(f"  Max frequency: {max_freq}")
    if word_count > 0:
        print(f"  Bytes/word: {len(data) / word_count:.1f}")
    print(f"  Output: {output_path}")


def main() -> None:
    if len(sys.argv) < 3:
        print("Usage: python3 dict_builder.py INPUT.json OUTPUT.dict")
        print()
        print("Builds a compressed patricia trie binary dictionary from a")
        print("frequency JSON file (format: {\"word\": count, ...}).")
        sys.exit(1)

    build_dict(sys.argv[1], sys.argv[2])


if __name__ == "__main__":
    main()
