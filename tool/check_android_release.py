#!/usr/bin/env python3
"""Check reflection entry points in the actual shrunk APK, not debug bytecode."""
import struct
import sys
import zipfile


def constructors(data):
    def u32(offset):
        return struct.unpack_from("<I", data, offset)[0]

    def leb(offset):
        value = shift = 0
        while True:
            byte = data[offset]
            offset += 1
            value |= (byte & 127) << shift
            if not byte & 128:
                return value, offset
            shift += 7

    strings = []
    for i in range(u32(56)):
        offset = u32(u32(60) + 4 * i)
        _, offset = leb(offset)
        strings.append(data[offset:data.index(b"\0", offset)].decode("utf-8", errors="replace"))
    types = [strings[u32(u32(68) + 4 * i)] for i in range(u32(64))]
    methods_offset = u32(92)
    for i in range(u32(96)):
        definition = u32(100) + i * 32
        cls = types[u32(definition)]
        offset = u32(definition + 24)
        if not offset:
            continue
        counts = []
        for _ in range(4):
            count, offset = leb(offset)
            counts.append(count)
        for _ in range(counts[0] + counts[1]):
            _, offset = leb(offset)
            _, offset = leb(offset)
        method_index = 0
        for _ in range(counts[2]):
            delta, offset = leb(offset)
            flags, offset = leb(offset)
            code, offset = leb(offset)
            method_index += delta
            _, proto, name = struct.unpack_from("<HHI", data, methods_offset + method_index * 8)
            if strings[name] != "<init>" or not code or not flags & 1:
                continue
            params = u32(u32(76) + proto * 12 + 8)
            signature = ()
            if params:
                signature = tuple(types[struct.unpack_from("<H", data, params + 4 + n * 2)[0]]
                                  for n in range(u32(params)))
            yield cls, signature


def main(apk):
    required = {
        ("Landroidx/work/impl/WorkDatabase_Impl;", ()),
        ("Lorg/poulapp/poulpoints/WidgetCommandWorker;",
         ("Landroid/content/Context;", "Landroidx/work/WorkerParameters;")),
    }
    required.add(("Lorg/poulapp/poulpoints/CloudSyncWorker;",
                  ("Landroid/content/Context;", "Landroidx/work/WorkerParameters;")))
    found = set()
    with zipfile.ZipFile(apk) as archive:
        for name in archive.namelist():
            if name.startswith("classes") and name.endswith(".dex"):
                found.update(constructors(archive.read(name)))
    missing = required - found
    if missing:
        for cls, signature in sorted(missing):
            print(f"MISSING public constructor: {cls} {signature}", file=sys.stderr)
        return 1
    print("PASS: Room, cloud-worker and widget-worker constructors retained in release APK.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1]))
