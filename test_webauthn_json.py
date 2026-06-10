import json
from webauthn import verify_registration_response
from webauthn.helpers import parse_registration_credential_json

data = {
    "id": "A" * 129,
    "rawId": "A" * 129,
    "type": "public-key",
    "response": {
        "attestationObject": "A" * 129,
        "clientDataJSON": "A" * 129
    }
}
try:
    cred = parse_registration_credential_json(data)
    verify_registration_response(
        credential=cred,
        expected_challenge=b"A"*32,
        expected_origin="https://forgefit.ghome.it",
        expected_rp_id="forgefit.ghome.it",
        require_user_verification=False,
    )
except Exception as e:
    import traceback
    traceback.print_exc()
