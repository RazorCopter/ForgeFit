import json
import base64
from webauthn import verify_registration_response
from webauthn.helpers import parse_registration_credential_json

# Let's see if we can reproduce this error.
# If we try to decode a 129-char base64 string, python's base64 module raises:
try:
    # 129 chars of 'A'
    s = "A" * 129
    # Add padding to make it a multiple of 4? No, python's base64.b64decode will complain
    # if we pass 129 characters without padding.
    base64.b64decode(s + "===")
except Exception as e:
    print(f"Exception 1: {e}")

try:
    base64.b64decode("A" * 129)
except Exception as e:
    print(f"Exception 2: {e}")

try:
    base64.urlsafe_b64decode("A" * 129)
except Exception as e:
    print(f"Exception 3: {e}")
