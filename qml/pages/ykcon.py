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

    def _search(self, creds, query, show_hidden):
        hits = []
        for c in creds:
            cred_id = _string_id(c)
            if not show_hidden and is_hidden(c):
                continue
            if cred_id == query:
                return [c]
            if query.lower() in cred_id.lower():
                hits.append(c)
        return hits

    def getKeys(self):

        could_register = False

        for device, info in list_all_devices():
            # The info object provides details about the YubiKey
            if info.version >= (5, 0, 0):
                connection, _, _ = connect_to_device(
                    serial=info.serial,
                    connection_types=[SmartCardConnection]
                )
                with connection:
                    could_register = True
                    mySession = OathSession(connection)
                    entries = mySession.calculate_all()
                    codes = []
                    for key in entries:
                        cred = key
                        code = entries[key]
                        code_dct = {'cred': cred,
                                    'code': code
                                   }
                        codes.append(code_dct)

                    if len(codes) > 0:
                        pyotherside.send(
                            'keys',
                            json.dumps(
                                codes,
                                default=dumper,
                                indent=2
                            )
                        )
                    else:
                        pyotherside.send('no_key')
        if not could_register:
            pyotherside.send('no_key')

    def writeKey(self, name, secret, hash_algo, issuer='', digits=6):

        new_credentials = CredentialData(name,
            OATH_TYPE.TOTP,
            HASH_ALGORITHM.SHA1,
            parse_b32_key(secret)
        )
        if '256' in hash_algo:
            new_credentials.hash_algorithm = HASH_ALGORITHM.SHA256
        if '512' in hash_algo:
            new_credentials.hash_algorithm = HASH_ALGORITHM.SHA512
        new_credentials.issuer = issuer
        new_credentials.digits = int(digits)

        for device, info in list_all_devices():
            # The info object provides details about the YubiKey
            if info.version >= (5, 0, 0):
                connection, _, _ = connect_to_device(
                    serial=info.serial,
                    connection_types=[SmartCardConnection]
                )
                with connection:
                    mySession = OathSession(connection)

    def deleteKey(self, name):
        for device, info in list_all_devices():
            # The info object provides details about the YubiKey
            if info.version >= (5, 0, 0):
                connection, _, _ = connect_to_device(
                    serial=info.serial,
                    connection_types=[SmartCardConnection]
                )
                with connection:
                    could_register = True
                    mySession = OathSession(connection)
                    creds = mySession.list_credentials()
                    hits = _search(creds, name, True)
                    if len(hits) == 0:
                        pyotherside.send("key_not_found")
                    elif len(hits) == 1:
                        cred = hits[0]
                        session.delete_credential(cred.id)
                        pyotherside.send(f"key_deleted:{name}")

        _init_session(ctx, password, remember)
        session = ctx.obj["session"]
        creds = session.list_credentials()
        hits = _search(creds, query, True)
        if len(hits) == 0:
            click.echo("No matches, nothing to be done.")
        elif len(hits) == 1:
            cred = hits[0]
            if force or (
                click.confirm(
                    f"Delete account: {_string_id(cred)} ?",
                    default=False,
                    err=True,
                )
            ):
                session.delete_credential(cred.id)
                click.echo(f"Deleted {_string_id(cred)}.")
            else:
                click.echo("Deletion aborted by user.")

        else:
            _error_multiple_hits(ctx, hits)

def dumper(obj):
    """JSON serialization of bytes"""
    if isinstance(obj, bytes):
        return obj.decode()
    try:
        return obj.toJSON()
    except:
        return obj.__dict__

ykcon = Ykcon()
