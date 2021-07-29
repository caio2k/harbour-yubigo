# This Python file uses the following encoding: utf-8

# Some of the code may be taken from https://github.com/Yubico/yubioath-desktop/blob/main/py/yubikey.py

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

        could_register = False

        for device, info in list_all_devices():
            if info.version >= (5, 0, 0):  # The info object provides details about the YubiKey
                connection, _, _ = connect_to_device(serial=info.serial, connection_types=[SmartCardConnection])
                with connection:
                    could_register = True
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

                    if len(codes) > 0:
                        pyotherside.send('keys', json.dumps(codes, default=dumper, indent=2))
                    else:
                        pyotherside.send('no_key')
        if not could_register:
            pyotherside.send('no_key')

    def writeKey(self, name, secret, hash_algo, issuer='', digits=6):

        new_credentials = CredentialData(name,  OATH_TYPE.TOTP, HASH_ALGORITHM.SHA1, parse_b32_key(secret))

        if '256' in hash_algo:
            new_credentials.hash_algorithm = HASH_ALGORITHM.SHA256
        if '512' in hash_algo:
            new_credentials.hash_algorithm = HASH_ALGORITHM.SHA512
        new_credentials.issuer = issuer
        new_credentials.digits = int(digits)

        for device, info in list_all_devices():
            if info.version >= (5, 0, 0):  # The info object provides details about the YubiKey
                connection, _, _ = connect_to_device(serial=info.serial, connection_types=[SmartCardConnection])
                with connection:
                    mySession = OathSession(connection)
                    mySession.put_credential(credential_data=new_credentials)

def dumper(obj):
    """JSON serialization of bytes"""
    if isinstance(obj, bytes):
        return obj.decode()
    try:
        return obj.toJSON()
    except: # pylint: disable=bare-except
        return obj.__dict__

ykcon = Ykcon()
