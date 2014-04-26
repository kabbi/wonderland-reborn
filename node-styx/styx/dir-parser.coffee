util = require "util"
Dissolve = require "dissolve"
StyxParser = require "./parser"

StyxDirParser = module.exports = (callback) ->
    # Call dissolve constructor instead of StyxParser's
    # to do our own parsing loop
    Dissolve.call @

    # TODO: some error handling here
    @loop (end) ->
        @dir().tap ->
            callback? @vars
            @vars = {}

util.inherits StyxDirParser, StyxParser

StyxDirParser::dir = () ->
    @uint16le("stat_len").tap ->
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

