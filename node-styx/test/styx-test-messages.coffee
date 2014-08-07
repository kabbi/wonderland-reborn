
module.exports = [
    encoded: new Buffer "1300000064ffff002000000600395032303030", "hex"
    decoded:
        type: "Tversion"
        tag: 0xFFFF
        messageSize: 8192
        protocol: "9P2000"
,
    encoded: new Buffer "1c0000006601002a00000005006b616262690800617574686e616d65", "hex"
    decoded:
        type: "Tauth"
        tag: 1
        authFid: 42
        userName: "kabbi"
        authName: "authname"
,
    encoded: new Buffer "090000006c01006400", "hex"
    decoded:
        type: "Tflush"
        tag: 1
        oldTag: 100
,
    encoded: new Buffer "1f0000006801000a0000001400000004007a7562720800617574686e616d65", "hex"
    decoded:
        type: "Tattach"
        tag: 1
        fid: 10
        authFid: 20
        userName: "zubr"
        authName: "authname"
,
    encoded: new Buffer "320000006e010064000000c800000005000400736f6d6504006c6f6e670400706174680400686572650700666f6c6c6f7773", "hex"
    decoded:
        type: "Twalk"
        tag: 1
        fid: 100
        newFid: 200
        pathEntries: ["some", "long", "path", "here", "follows"]
,
    encoded: new Buffer "0c0000007001000a00000014", "hex"
    decoded:
        type: "Topen"
        tag: 1
        fid: 10
        mode: 20
,
    encoded: new Buffer "1a000000720100f20000000800736f6d654e616d65020000000a", "hex"
    decoded:
        type: "Tcreate"
        tag: 1
        fid: 242
        name: "someName"
        perm: 2
        mode: 10
,
    encoded: new Buffer "170000007401000a0000001027000000000000204e0000", "hex"
    decoded:
        type: "Tread"
        tag: 1
        fid: 10
        offset: 10000
        count: 20000
,
    encoded: new Buffer "250000007608000a00000010270000000000000e0000006875676520646174612068657265", "hex"
    decoded:
        type: "Twrite"
        tag: 8
        fid: 10
        offset: 10000,
        data: new Buffer "huge data here", "utf8"
,
    encoded: new Buffer "0b000000780100e7030000", "hex"
    decoded:
        type: "Tclunk"
        tag: 1
        fid: 999
,
    encoded: new Buffer "0b0000007a0100de000000", "hex"
    decoded:
        type: "Tremove"
        tag: 1
        fid: 222
,
    encoded: new Buffer "0b0000007c010003000000", "hex"
    decoded:
        type: "Tstat"
        tag: 1
        fid: 3
,
    encoded: new Buffer "4a0000007e0100090000003d003b00000000000000000000000000000000000000002200000000000000c1110000de030000000000000600686767676767030075737303006769690000", "hex"
    decoded:
        type: "Twstat"
        tag: 1
        fid: 9
        reservedType: 0
        reservedDev: 0
        qid:
            type: 0
            version: 0
            path: 0
        mode: 34
        lastAccessTime: 0
        lastModificationTime: 4545
        length: 990
        name: "hggggg"
        ownerName: "uss"
        groupName: "gii"
        lastModifierName: ""
,
    # TODO: rmsgs below are not realy good in terms of testing parser functionality.
    # Consider improving with some random data

    encoded: new Buffer "1300000065ffff002000000600395032303030", "hex"
    decoded:
        type: "Rversion"
        tag: 0xFFFF
        messageSize: 8192
        protocol: "9P2000"
,
    encoded: new Buffer "1400000069000080000000000000000000000000", "hex"
    decoded:
        type: "Rattach"
        tag: 0
        qid:
            type: 128
            version: 0
            path: 0
,
    encoded: new Buffer "090000006f01000000", "hex"
    decoded:
        type: "Rwalk"
        tag: 1
        pathEntries: []
,
    encoded: new Buffer "1800000071030080000000000000000000000000e81f0000", "hex"
    decoded:
        type: "Ropen"
        tag: 3
        qid:
            type: 128
            version: 0
            path: 0
        ioUnit: 8168
,
    encoded: new Buffer "07000000790700", "hex"
    decoded:
        type: "Rclunk"
        tag: 7
,
    encoded: new Buffer "0b0000007706002a000000", "hex"
    decoded:
        type: "Rwrite"
        tag: 6
        count: 42
]