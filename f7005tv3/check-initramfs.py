"""Find a newc archive with both trial files in the selected FIT payload."""
import lzma
import re
import sys
from pathlib import Path

payload = Path(sys.argv[1]).read_bytes()
required = {b'init', b'www/f7005tv3-ram-trial.txt'}


def matches(data, offset):
    found = set()
    start = offset
    while data[offset:offset+6] in (b'070701', b'070702'):
        header = data[offset:offset+110]
        try:
            size = int(header[54:62], 16)
            length = int(header[94:102], 16)
        except ValueError:
            return False
        name = data[offset+110:offset+110+length-1].removeprefix(b'./')
        body = start + ((offset+110+length-start+3) & ~3)
        if length < 1 or body+size > len(data):
            return False
        if name == b'TRAILER!!!':
            return found == required
        if name in required and size:
            found.add(name)
        offset = start + ((body+size-start+3) & ~3)
    return False


def contains(data):
    for m in re.finditer(b'07070[12]', data):
        if matches(data, m.start()):
            return True
    return False


if contains(payload):
    sys.exit(0)
import zlib
for magic, decoder in [(b'\x1f\x8b\x08', lambda: zlib.decompressobj(31)),
                       (b'\xfd7zXZ\x00', lzma.LZMADecompressor)]:
    for hit in re.finditer(re.escape(magic), payload):
        try:
            obj = decoder()
            raw = obj.decompress(payload[hit.start():], 128 << 20)
            if obj.eof and contains(raw):
                sys.exit(0)
        except (zlib.error, lzma.LZMAError):
            continue
sys.exit('Selected payload lacks a verified newc initramfs with init and trial marker')
