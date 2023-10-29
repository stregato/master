import ctypes
import platform
import os
import json
from dataclasses import dataclass, asdict
from datetime import datetime, datetime
import pytz
import pkg_resources


def load_lib():
    lib = {
        "Windows": "windows/woland.dll",
        "Linux": "linux/libwoland.so",
        "Darwin": "macos/libwoland.dylib",
    }
    os_name = platform.system()
    package_dir = pkg_resources.get_distribution('poland').location
    path = os.path.join(package_dir, lib[os_name])
    return ctypes.CDLL(path)


def json_serial(obj):
    """JSON serializer for objects not serializable by default json code"""

    if isinstance(obj, datetime):
        if not obj.tzinfo:
            obj = pytz.utc.localize(obj)
        return obj.isoformat()
    raise TypeError ("Type %s not serializable" % type(obj))

def e8(s): return ctypes.c_char_p(s.encode("utf-8"))
def j8(s): return json.dumps(s).encode("utf-8")
def o8(o): return json.dumps(asdict(o), default=json_serial).encode("utf-8")


class Result(ctypes.Structure):
    _fields_ = [("res", ctypes.c_char_p), ("err", ctypes.c_char_p)]


def r2d(r):
    if r.err:
        raise Exception(r.err.decode("utf-8"))
    if r.res == None:
        return None
    return json.loads(r.res.decode("utf-8"))

lib = load_lib()
lib.wlnd_start.argtypes = [ctypes.c_char_p, ctypes.c_char_p]
lib.wlnd_start.restype = Result
lib.wlnd_stop.argtypes = []
lib.wlnd_stop.restype = Result
lib.wlnd_factoryReset.argtypes = []
lib.wlnd_factoryReset.restype = Result
lib.wlnd_getConfig.argtypes = [ctypes.c_char_p, ctypes.c_char_p]
lib.wlnd_getConfig.restype = Result
lib.wlnd_setConfig.argtypes = [
    ctypes.c_char_p, ctypes.c_char_p, ctypes.c_char_p]
lib.wlnd_setConfig.restype = Result
lib.wlnd_newIdentity.argtypes = [ctypes.c_char_p]
lib.wlnd_newIdentity.restype = Result
lib.wlnd_setIdentity.argtypes = [ctypes.c_char_p]
lib.wlnd_setIdentity.restype = Result
lib.wlnd_encodeAccess.argtypes = [
    ctypes.c_char_p, ctypes.c_char_p, ctypes.c_char_p, ctypes.c_char_p, ctypes.c_char_p]
lib.wlnd_encodeAccess.restype = Result
lib.wlnd_decodeAccess.argtypes = [ctypes.c_char_p, ctypes.c_char_p]
lib.wlnd_decodeAccess.restype = Result
lib.wlnd_createSafe.argtypes = [ctypes.c_char_p,
                                ctypes.c_char_p, ctypes.c_char_p, ctypes.c_char_p]
lib.wlnd_createSafe.restype = Result
lib.wlnd_openSafe.argtypes = [
    ctypes.c_char_p, ctypes.c_char_p, ctypes.c_char_p]
lib.wlnd_openSafe.restype = Result
lib.wlnd_closeSafe.argtypes = [ctypes.c_int32]
lib.wlnd_closeSafe.restype = Result
lib.wlnd_listFiles.argtypes = [
    ctypes.c_int32, ctypes.c_char_p, ctypes.c_char_p]
lib.wlnd_listFiles.restype = Result
lib.wlnd_listDirs.argtypes = [ctypes.c_int32, ctypes.c_char_p, ctypes.c_char_p]
lib.wlnd_listDirs.restype = Result
lib.wlnd_putCString.argtypes = [
    ctypes.c_int32, ctypes.c_char_p, ctypes.c_char_p, ctypes.c_char_p]
lib.wlnd_putCString.restype = Result
lib.wlnd_putFile.argtypes = [ctypes.c_int32,
                             ctypes.c_char_p, ctypes.c_char_p, ctypes.c_char_p]
lib.wlnd_putFile.restype = Result
lib.wlnd_getCString.argtypes = [
    ctypes.c_int32, ctypes.c_char_p, ctypes.c_char_p]
lib.wlnd_getCString.restype = Result
lib.wlnd_getFile.argtypes = [ctypes.c_int32, ctypes.c_char_p, ctypes.c_char_p]
lib.wlnd_getFile.restype = Result
lib.wlnd_setUsers.argtypes = [ctypes.c_int32, ctypes.c_char_p, ctypes.c_char_p]
lib.wlnd_setUsers.restype = Result
lib.wlnd_getUsers.argtypes = [ctypes.c_int32]
lib.wlnd_getUsers.restype = Result
lib.wlnd_getLogs.argtypes = []
lib.wlnd_getLogs.restype = Result
lib.wlnd_setLogLevel.argtypes = [ctypes.c_int]
lib.wlnd_setLogLevel.restype = Result

