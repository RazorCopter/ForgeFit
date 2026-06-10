from webauthn import generate_registration_options
from webauthn.helpers import base64url_to_bytes

for i in range(100):
    opts = generate_registration_options(rp_id="test", rp_name="test", user_id=b"test", user_name="test")
    try:
        base64url_to_bytes(opts.challenge)
    except Exception as e:
        if "129" in str(e):
            print("FOUND 129 ERROR:", e)
            break
else:
    print("No 129 error found in 100 iterations.")
