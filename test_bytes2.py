from webauthn.helpers import bytes_to_base64url

b = b"\x87\x00"
print(bytes_to_base64url(b))
