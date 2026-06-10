from webauthn import generate_registration_options
import base64
options = generate_registration_options(
    rp_id="test",
    rp_name="test",
    user_id=b"test",
    user_name="test"
)
print("Challenge length:", len(options.challenge))
print("Challenge value:", options.challenge)
