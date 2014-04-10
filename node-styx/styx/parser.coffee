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
    @tap name, ->
        @uint8("type")
        .uint32le("version")
        .uint64le("path")

StyxParser::dir = (name) ->
    @uint16le("stat_len").uint16le("stat_len").tap ->
        delete @vars.stat_len
        @uint16le("reservedType")
        .uint32le("reservedDev")
        .qid("qid")
        .uint32le("mode")
        .uint32le("lastAccessTime")
        .uint32le("lastModificationTime")
        .uint64le("length")
        .string16("name")
        .string16("ownerName")
        .string16("groupName")
        .string16("lastModifierName")

