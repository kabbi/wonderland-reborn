util = require "util"
winston = require "winston"
events = require "events"

StyxEncoder = require "./encoder"
StyxParser = require "./parser"

StyxStream = module.exports = (@target) ->
    return new StyxStream() unless @ instanceof StyxStream
    events.EventEmitter.call @

    @parser = new StyxParser (msg) =>
        @emit "data", msg
    @encoder = new StyxEncoder()
    target.pipe @parser
    @encoder.pipe target

    @parser.on "end", ->
        @encoder.end()

    return

util.inherits StyxStream, events.EventEmitter

StyxStream::write = (data) ->
    @encoder.encode data

StyxStream::end = ->
    @encoder.end()