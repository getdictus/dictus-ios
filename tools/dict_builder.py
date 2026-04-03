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
    """Serialize trie to binary DTRI format using BFS order.
    Returns (data_bytes, node_count, word_count).

    BFS ensures children of each parent are stored contiguously,
    which the C++ reader requires for sibling scanning.
    root_child_count is stored in header byte 20."""
    from collections import deque

    # Collect nodes in BFS order (siblings contiguous at every level)
    nodes_order: list[TrieNode] = []
    queue: deque[TrieNode] = deque()
    for child in root.child_list():
        queue.append(child)
    while queue:
        node = queue.popleft()
        nodes_order.append(node)
        for child in node.child_list():
            queue.append(child)

    node_count = len(nodes_order)
    word_count = sum(1 for n in nodes_order if n.is_terminal)

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

    # Compute offsets with iterative pointer size refinement.
    # Each iteration uses ONLY the previous iteration's offsets to determine
    # pointer sizes, then builds a fresh offset map. This avoids mixing
    # current- and previous-iteration values (BFS children come later in array).
    offsets: dict[int, int] = {}
    for attempt in range(10):
        prev_offsets = dict(offsets)
        offsets = {}
        offset = HEADER_SIZE
        for node in nodes_order:
            offsets[id(node)] = offset
            if not node.children:
                ptr_bytes = 0
            elif attempt == 0:
                ptr_bytes = 4
            else:
                first_child = node.child_list()[0]
                child_off = prev_offsets.get(id(first_child), 0xFFFFFFFF)
                if child_off <= 0xFFFF:
                    ptr_bytes = 2
                elif child_off <= 0xFFFFFF:
                    ptr_bytes = 3
                else:
                    ptr_bytes = 4
            offset += node_size(node, ptr_bytes)
        if offsets == prev_offsets:
            break

    # Write
    buf = bytearray()
    root_child_count = len(root.children)
    buf.extend(MAGIC)
    buf.extend(struct.pack("<H", VERSION))
    buf.extend(struct.pack("<H", 0))  # flags
    buf.extend(struct.pack("<I", node_count))
    buf.extend(struct.pack("<I", word_count))
    header_max_freq = min(max_freq, 0xFFFFFFFF)
    buf.extend(struct.pack("<I", header_max_freq))
    buf.extend(struct.pack("<B", root_child_count))
    buf.extend(b"\x00" * 11)
    assert len(buf) == HEADER_SIZE

    log_max = math.log(1 + max_freq) if max_freq > 0 else 1.0

    for node in nodes_order:
        has_children = bool(node.children)
        multi_char = len(node.chars) > 1

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
            norm = int(65535 * math.log(1 + node.frequency) / log_max) if node.frequency > 0 else 0
            norm = min(65535, max(0, norm))
            buf.extend(struct.pack("<H", norm))
        if has_children:
            buf.append(len(node.children))
            child_off = offsets[id(node.child_list()[0])]
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
