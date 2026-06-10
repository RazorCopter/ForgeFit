import inspect
from webauthn import verify_registration_response

source = inspect.getsource(verify_registration_response)
print(source)
