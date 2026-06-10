from webauthn import generate_registration_options

options = generate_registration_options(
    rp_id="localhost",
    rp_name="test",
    user_id=b"123",
    user_name="test",
)
print("Type of options.challenge:", type(options.challenge))
