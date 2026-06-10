import json
from webauthn.helpers import parse_registration_credential_json

data = {
    "id": "123",
    "rawId": "123",
    "type": "public-key",
    "response": {
        "clientDataJSON": "123",
        "attestationObject": "456"
    }
}
try:
    cred = parse_registration_credential_json(data)
    print(cred)
except Exception as e:
    print(repr(e))
