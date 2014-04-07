util = require "util"
winston = require "winston"
Dissolve = require "dissolve"

messages = require "./messages"

StyxParser = module.exports = (callback) ->
    Dissolve.call @

    # TODO: some error handling here
    @loop (end) ->
        @uint32("length").uint8("type").uint16("tag").tap ->
            delete @vars.length
            message = messages[@vars.type]
            return unless message
            @vars.type = message.name
            message.decode.call @, ->
                callback @vars
                @vars = {}

util.inherits StyxParser, Dissolve

StyxParser::string16 = (name) ->
    len = [name, "len"].join "_"

    @uint16le(len).tap ->
        @buffer(name, this.vars[len]).tap ->
            delete this.vars[len];
            this.vars[name] = this.vars[name].toString "utf8"

StyxParser::qid = (name) ->
    @uint64le("path").uint32le("version").uint32le("qidType")

StyxParser::dir = (name) ->
    @string16("name").string16("uid").string16("gid").string16("lastModifierUid")
    .qid("qid").uint32("permissions").uint32("lastAccessTime").uint32("lastModificationTime")
    .uint64("length").uint32("serverType").uint32("serverSubType")
