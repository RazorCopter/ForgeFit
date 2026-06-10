import inspect
from webauthn import verify_registration_response

sig = inspect.signature(verify_registration_response)
print("verify_registration_response signature:", sig)
for param in sig.parameters.values():
    print(f"  {param.name}: {param.annotation}")
