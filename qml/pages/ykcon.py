# This Python file uses the following encoding: utf-8
import pyotherside
import json
from ykman.device import connect_to_device, list_all_devices
from yubikit.core.smartcard import SmartCardConnection
from yubikit.oath import (
    OathSession,
    CredentialData,
    OATH_TYPE,
    HASH_ALGORITHM,
    parse_b32_key,
    _format_cred_id,
    Credential,
    Code,
)


class Ykcon:

    def __init__(self):
        pass

    def getKeys(self):

        for device, info in list_all_devices():
            if info.version >= (5, 0, 0):  # The info object provides details about the YubiKey
                connection, _, _ = connect_to_device(serial=info.serial, connection_types=[SmartCardConnection])
                with connection:
                    mySession = OathSession(connection)
                    entries = mySession.calculate_all()
                    codes = []
                    for key in entries:
                        cred = key
                        code = entries[key]
                        code_dct = {'cred':cred,
                                    'code' :code
                                   }
                        codes.append(code_dct)

                    pyotherside.send('Key', json.dumps(codes, default=dumper, indent=2))

def dumper(obj):
    """JSON serialization of bytes"""
    if isinstance(obj, bytes):
        return obj.decode()
    try:
        return obj.toJSON()
    except: # pylint: disable=bare-except
        return obj.__dict__

ykcon = Ykcon()
