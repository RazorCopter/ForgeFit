from webauthn import generate_registration_options
from webauthn.helpers import base64url_to_bytes
import binascii

options = generate_registration_options(
    rp_id="test",
    rp_name="test",
    user_id=b"test",
    user_name="test"
)

challenge = options.challenge
print(f"Challenge type: {type(challenge)}")
print(f"Challenge value: {challenge}")

try:
    decoded = base64url_to_bytes(challenge)
except Exception as e:
    print(f"Exception decoding challenge: {type(e).__name__}: {e}")
