import json
import base64
from webauthn.helpers import base64url_to_bytes

# What if base64url_to_bytes receives a bytes object containing a challenge?
# I already tested that and it raises UnicodeDecodeError!
b = b'\x87\x00\x00'
try:
    base64url_to_bytes(b)
except Exception as e:
    print(repr(e))
