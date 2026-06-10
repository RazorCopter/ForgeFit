import inspect
from webauthn.helpers.parse_client_data_json import parse_client_data_json

source = inspect.getsource(parse_client_data_json)
print(source)
