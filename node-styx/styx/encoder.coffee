util = require "util"
winston = require "winston"
Concentrate = require "concentrate"

messages = require "./messages"

StyxEncoder = module.exports = ->
    return new StyxEncoder() unless @ instanceof StyxEncoder
    Concentrate.call @
    undefined # is that needed to make this function like constructor?

util.inherits StyxEncoder, Concentrate

StyxEncoder::encode = (message) ->
    code = messages.codeByName message.type
    buffer = messages[code].encode.call new StyxEncoder, message
    result = @uint32le(buffer.length + 4 + 1 + 2).uint8(code).uint16le(message.tag).buffer(buffer).result()
    do @flush # a bit of hack here to clear state after result()
    result

StyxEncoder::uint64le = (number) ->
    # TODO: IMPORTANT: can we have 64bit ints?
    @uint32le(number & 0xFFFFFFFF).uint32le(0)

StyxEncoder::string16 = (str) ->
    @uint16le(str.length).buffer(new Buffer str, "utf8")

StyxEncoder::qid = (qid) ->
    @uint64le(qid.path).uint32le(qid.version).uint32le(qid.qidType)

