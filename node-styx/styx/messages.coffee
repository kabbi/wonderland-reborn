
module.exports =
    100:
        name: 'Tversion'
        decode: (finish) ->
            @uint32le("messageSize").string16("protocol").tap finish
        encode: (msg) ->
            @uint32le(msg.messageSize).string16(msg.protocol).result()
    101:
        name: 'Rversion'
        decode: (finish) ->
            @uint32le("messageSize").string16("protocol").tap finish
        encode: (msg) ->
            @uint32le(msg.messageSize).string16(msg.protocol).result()
    102:
        name: 'Tauth'
        decode: (finish) ->
            @uint32le("authFid").string16("userName").string16("authName").tap finish
        encode: (msg) ->
            @uint32le(msg.authFid).string16(msg.userName).string16(msg.authName).result()
    103:
        name: 'Rauth'
        decode: (finish) ->
            finish()
        encode: (msg) ->
            @result()
    104:
        name: 'Tattach'
        decode: (finish) ->
            @uint32le("fid").uint32le("authFid").string16("userName").string16("authName").tap finish
        encode: (msg) ->
            @uint32le(msg.fid).uint32le(msg.authFid).string16(msg.userName).string16(msg.authName).result()
    105:
        name: 'Rattach'
        decode: (finish) ->
            finish()
        encode: (msg) ->
            @result()
    106:
        name: 'Terror'
        decode: (finish) ->
            @string16("message").tap finish
        encode: (msg) ->
            @string16(msg.message).result()
    107:
        name: 'Rerror'
        decode: (finish) ->
            finish()
        encode: (msg) ->
            @result()
    108:
        name: 'Tflush'
        decode: (finish) ->
            @uint16le("oldTag").tap finish
        encode: (msg) ->
            @uint16le(msg.oldTag).result()
    109:
        name: 'Rflush'
        decode: (finish) ->
            finish()
        encode: (msg) ->
            @result()
    110:
        name: 'Twalk'
        decode: (finish) ->
            @uint32le("fid").uint32le("newFid").uint16le("numberOfEntries").tap ->
                @loop("pathEntries", (end) ->
                    @string16("path")
                    if @vars.pathEntries.length is @vars.numberOfEntries - 1
                        do end
                ).tap ->
                    @vars.pathEntries = @vars.pathEntries.map (item) -> item.path
                    delete @vars.numberOfEntries
                    finish.call @
        encode: (msg) ->
            @uint32le(msg.fid).uint32le(msg.newFid).uint16le(msg.pathEntries.length)
            for entry in msg.pathEntries
                @string16 entry
            @result()
    111:
        name: 'Rwalk'
        decode: (finish) ->
            finish()
        encode: (msg) ->
            @result()
    112:
        name: 'Topen'
        decode: (finish) ->
            @uint32le("fid").uint8("mode").tap finish
        encode: (msg) ->
            @uint32le(msg.fid).uint8(msg.mode).result()
    113:
        name: 'Ropen'
        decode: (finish) ->
            finish()
        encode: (msg) ->
            @result()
    114:
        name: 'Tcreate'
        decode: (finish) ->
            @uint32le("fid").string16("name").uint32le("perm").uint8("mode").tap finish
        encode: (msg) ->
            @uint32le(msg.fid).string16(msg.name).uint32le(msg.perm).uint8(msg.mode).result()
    115:
        name: 'Rcreate'
        decode: (finish) ->
            finish()
        encode: (msg) ->
            @result()
    116:
        name: 'Tread'
        decode: (finish) ->
            @uint32le("fid").uint64le("offset").uint32le("count").tap finish
        encode: (msg) ->
            @uint32le(msg.fid).uint64le(msg.offset).uint32le(msg.count).result()
    117:
        name: 'Rread'
        decode: (finish) ->
            finish()
        encode: (msg) ->
            @result()
    118:
        name: 'Twrite'
        decode: (finish) ->
            @uint32le("fid").uint64le("offset").uint32le("count").buffer("data", "count").tap ->
                delete @vars.count
                finish.call @
        encode: (msg) ->
            @result()
    119:
        name: 'Rwrite'
        decode: (finish) ->
            finish()
        encode: (msg) ->
            @result()
    120:
        name: 'Tclunk'
        decode: (finish) ->
            @uint32le("fid").tap finish
        encode: (msg) ->
            @uint32le(msg.fid).result()
    121:
        name: 'Rclunk'
        decode: (finish) ->
            finish()
        encode: (msg) ->
            @result()
    122:
        name: 'Tremove'
        decode: (finish) ->
            @uint32le("fid").tap finish
        encode: (msg) ->
            @uint32le(msg.fid).result()
    123:
        name: 'Rremove'
        decode: (finish) ->
            finish()
        encode: (msg) ->
            @result()
    124:
        name: 'Tstat'
        decode: (finish) ->
            @uint32le("fid").tap finish
        encode: (msg) ->
            @uint32le(msg.fid).result()
    125:
        name: 'Rstat'
        decode: (finish) ->
            finish()
        encode: (msg) ->
            @result()
    126:
        name: 'Twstat'
        decode: (finish) ->
            @uint32le("fid").dir("stat").tap finish
        encode: (msg) ->
            buffer = (new @constructor()).dir(msg).result()
            @uint32le(msg.fid).int16le(buffer.length).buffer(buffer).result()
    127:
        name: 'Rwstat'
        decode: (finish) ->
            finish()
        encode: (msg) ->
            @result()

    # TODO: redefine with reverse hashmap
    codeByName: (name) ->
        for own code, message of @
            return code if message.name is name
        undefined
        