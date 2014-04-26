exports.NO_FID = 0xFFFF
exports.NO_TAG = 0xFFFF
exports.VERSION = "9P2000"

exports.MODE_READ = 0x00
exports.MODE_WRITE = 0x01
exports.MODE_READ_WRITE = 0x02
exports.MODE_EXEC = 0x03
exports.MODE_TRUNCATE = 0x10
exports.MODE_REMOVE_ON_CLOSE = 0x40

exports.QID_TYPE_FILE = 0x00;
exports.QID_TYPE_TMP = 0x04;
exports.QID_TYPE_AUTH = 0x08;
exports.QID_TYPE_EXCL = 0x20;
exports.QID_TYPE_APPEND = 0x40;
exports.QID_TYPE_DIR = 0x80;

exports.EINUSE = "fid already in use"
exports.EBADFID = "bad fid"
exports.EOPEN = "fid already opened"
exports.ENOTFOUND = "file does not exist"
exports.ENOTDIR = "not a directory"
exports.EPERM = "permission denied"
exports.EBADARG = "bad argument"
exports.EEXISTS = "file already exists"
exports.EMODE = "open/create -- unknown mode"
exports.EOFFSET = "read/write -- bad offset"
exports.ECOUNT = "read/write -- count negative or exceeds msgsize"
exports.ENOTOPEN = "read/write -- on non open fid"
exports.EACCESS = "read/write -- not open in suitable mode"
exports.ENAME = "bad character in file name"
exports.EDOT = ". and .. are illegal names"