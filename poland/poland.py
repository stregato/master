import json
from options import CreateOptions, OpenOptions, ListOptions, Users, ListDirsOptions, PutOptions, GetOptions, SetUsersOptions
from woland import lib, e8, j8, o8, r2d
from typing import List, Union
from datetime import datetime
import base64

def start(dbPath, appPath):
    "start woland library with the provided db file and app path"
    r = lib.wlnd_start(e8(dbPath), e8(appPath))
    return r2d(r)


def stop():
    "stop woland library"
    lib.wlnd_stop()


def factoryReset():
    "reset the db to its initial state"
    r = lib.wlnd_factoryReset()
    return r2d(r)


def getConfig(node: str, key: str):
    "get a configuration value from the db"
    r = lib.wlnd_getConfig(e8(node), e8(key))
    return r2d(r)


def setConfig(node: str, key: str, value: str):
    "set a configuration value in the db"
    r = lib.wlnd_setConfig(e8(node), e8(key), e8(value))
    return r2d(r)


def encodeAccess(userId: str, safeName: str, creatorId: str, urls: List[str], aesKey: str = ""):
    "encode access to a safe"
    r = lib.wlnd_encodeAccess(e8(userId), e8(
        safeName), e8(creatorId), j8(urls), e8(aesKey))
    return r2d(r)


def decodeAccess(access: str):
    "decode access to a safe"
    r = lib.wlnd_decodeAccess(e8(access))
    return r2d(r)


class Identity():
    @staticmethod
    def fromJson(json: str):
        return Identity(json["i"], json.get("n"), json.get("e"), json.get("m"), json["p"], json.get("a"))

    @staticmethod
    def new(nick: str):
        r = lib.wlnd_newIdentity(e8(nick))
        return Identity.fromJson(r2d(r))

    @staticmethod
    def get(id: str):
        r = lib.wlnd_getIdentity(e8(id))
        return Identity.fromJson(r2d(r))

    def __init__(self, id: str, nick: str, email: str, modTime: str, private, avatar):
        self.id = id
        self.nick = nick
        self.email = email
        self.modTime = datetime.fromisoformat(modTime)
        self.private = private
        self.avatar = avatar

    def toJson(self):
        return json.dumps({"i": self.id, "n": self.nick, "e": self.email, "m": self.modTime.isoformat(), "p": self.private, "a": self.avatar})

    def set(self):
        r = lib.wlnd_setIdentity(e8(self.toJson()))
        return r2d(r)



class Safe():
    @staticmethod
    def create(creator: Identity, access: str, users: Users = {}, createOptions: CreateOptions = CreateOptions()):
        r = lib.wlnd_createSafe(e8(creator.toJson()), e8(
            access), j8(users), o8(createOptions))
        return r2d(r)

    def __init__(self, identity: Identity, access: str, openOptions: OpenOptions = OpenOptions()):
        r = lib.wlnd_openSafe(e8(identity.toJson()),
                              e8(access), o8(openOptions))
        for k, v in r2d(r).items():
            setattr(self, k, v)
        self.identity = identity
        self.access = access

    def close(self):
        r = lib.wlnd_closeSafe(self.hnd)
        return r2d(r)

    def listFiles(self, dir: str = "", listOptions: ListOptions = ListOptions()):
        r = lib.wlnd_listFiles(self.hnd, e8(dir), o8(listOptions))
        return r2d(r)

    def listDir(self, dir: str = "", listDirsOptions: ListDirsOptions = ListDirsOptions()):
        r = lib.wlnd_listDirs(self.hnd, e8(dir), o8(listDirsOptions))
        return r2d(r)

    def putBytes(self, name: str, data: bytes, putOptions: PutOptions = PutOptions()):
        data = base64.b64encode(data)
        r = lib.wlnd_putCString(self.hnd, e8(name), data, o8(putOptions))
        return r2d(r)

    def putFile(self, name: str, path: str, putOptions: PutOptions = PutOptions()):
        r = lib.wlnd_putFile(self.hnd, e8(name), e8(path), o8(putOptions))
        return r2d(r)

    def getBytes(self, name: str, getOptions: GetOptions = GetOptions()):
        r = lib.wlnd_getCString(self.hnd, e8(name), o8(getOptions))
        return base64.b64decode(r2d(r))

    def getFile(self, name: str, path: str, getOptions: GetOptions = GetOptions()):
        r = lib.wlnd_getFile(self.hnd, e8(name), e8(path), o8(getOptions))
        return r2d(r)

    def setUsers(self, users: Users, setUsersOptions: SetUsersOptions = SetUsersOptions()):
        r = lib.wlnd_setUsers(self.hnd, j8(users), o8(setUsersOptions))
        return r2d(r)

    def getUsers(self):
        r = lib.wlnd_getUsers(self.hnd)
        return r2d(r)


def test():
    start("/tmp/poland.db", "/tmp")
    i = Identity.new("test")
    access = encodeAccess(i.id, "test", i.id, ["file:///tmp/poland/"])
    Safe.create(i, access, {}, CreateOptions(wipe=True))
    safe = Safe(i, access, OpenOptions())
    print(safe.listFiles())
    safe.putBytes("test.txt", b"hello world")
    print(safe.listFiles())
    safe.close()
    stop()


if __name__ == "__main__":
    test()
