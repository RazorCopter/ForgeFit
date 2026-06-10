import json

try:
    json.loads(b'\x87\x00\x00')
except Exception as e:
    print("0x87 error:", repr(e))

try:
    json.loads(b'\xa3\x00\x00')
except Exception as e:
    print("0xa3 error:", repr(e))

try:
    json.loads(b'a\xc5\x00')
except Exception as e:
    print("0xc5 error:", repr(e))
