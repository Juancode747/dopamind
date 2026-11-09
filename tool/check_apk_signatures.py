"""Inspect actual release DEX generic signatures used by Gson (no mock plugins).

Usage: python check_apk_signatures.py app.apk [TypeToken binary name]
Returns 1 if R8 stripped a TypeToken subclass signature.
"""
import struct
import sys
import zipfile


class Dex:
    def __init__(self, data):
        self.data = data
        self.strings = []
        size, offset = struct.unpack_from('<II', data, 56)
        for i in range(size):
            start = self.u32(offset + i * 4)
            _, start = self.uleb(start)
            self.strings.append(data[start:data.index(b'\0', start)].decode('utf-8', errors='replace'))
        size, offset = struct.unpack_from('<II', data, 64)
        self.types = [self.strings[self.u32(offset + i * 4)] for i in range(size)]

    def u32(self, offset):
        return struct.unpack_from('<I', self.data, offset)[0]

    def uleb(self, offset):
        value = shift = 0
        while True:
            byte = self.data[offset]
            offset += 1
            value |= (byte & 127) << shift
            if byte < 128:
                return value, offset
            shift += 7

    def annotation(self, offset):
        type_id, offset = self.uleb(offset)
        size, offset = self.uleb(offset)
        fields = {}
        for _ in range(size):
            name, offset = self.uleb(offset)
            fields[self.strings[name]], offset = self.value(offset)
        return (self.types[type_id], fields), offset

    def value(self, offset):
        head = self.data[offset]
        offset += 1
        kind, width = head & 31, (head >> 5) + 1
        if kind == 0x1c:
            size, offset = self.uleb(offset)
            values = []
            for _ in range(size):
                value, offset = self.value(offset)
                values.append(value)
            return values, offset
        if kind == 0x1d:
            return self.annotation(offset)
        if kind == 0x1e:
            return None, offset
        if kind == 0x1f:
            return bool(head >> 5), offset
        value = int.from_bytes(self.data[offset:offset + width], 'little')
        if kind == 0x17:
            value = self.strings[value]
        elif kind == 0x18:
            value = self.types[value]
        return value, offset + width

    def token_subclasses(self, base):
        size, offset = struct.unpack_from('<II', self.data, 96)
        for i in range(size):
            cls, _, parent, _, _, annotations, _, _ = struct.unpack_from('<8I', self.data, offset + i * 32)
            if parent == 0xffffffff or self.types[parent] != base:
                continue
            signature = None
            if annotations:
                ann_set = self.u32(annotations)
                if ann_set:
                    for j in range(self.u32(ann_set)):
                        ann_offset = self.u32(ann_set + 4 + j * 4)
                        (kind, fields), _ = self.annotation(ann_offset + 1)
                        if kind == 'Ldalvik/annotation/Signature;':
                            signature = ''.join(fields['value'])
            yield self.types[cls], signature


token = sys.argv[2] if len(sys.argv) > 2 else 'com/google/gson/reflect/TypeToken'
results = []
with zipfile.ZipFile(sys.argv[1]) as apk:
    for name in apk.namelist():
        if name.startswith('classes') and name.endswith('.dex'):
            results.extend(Dex(apk.read(name)).token_subclasses(f'L{token};'))
for name, signature in results:
    print(f'{name}: {signature or "MISSING GENERIC SIGNATURE"}')
valid = bool(results) and all(signature for _, signature in results)
print('PASS: generic signatures retained' if valid else 'FAIL: Gson cannot recover generic type information')
sys.exit(0 if valid else 1)
