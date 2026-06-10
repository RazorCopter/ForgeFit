from webauthn import generate_registration_options
from webauthn.helpers import base64url_to_bytes
import sys

for i in range(100):
    opts = generate_registration_options(rp_id="test", rp_name="test", user_id=b"test", user_name="test")
    try:
        val = opts.challenge
        if isinstance(val, bytes):
            val = val.decode("utf-8")
        val += "=" * ((4 - len(val) % 4) % 4)
        import base64
        base64.urlsafe_b64decode(val)
    except Exception as e:
        if "129" in str(e):
            print("Challenge:", opts.challenge)
            print("Length bytes:", len(opts.challenge))
            
            val = opts.challenge.decode('utf-8', errors='replace')
            print("Decoded string length:", len(val))
            print("Decoded string + padding length:", len(val) + ((4 - len(val) % 4) % 4))
            break
