util = require "util"
winston = require "winston"
stream = require "stream"

StyxEncoder = require "./encoder"
StyxParser = require "./parser"

StyxStream = module.exports = (@target) ->
    return new StyxStream() unless @ instanceof StyxStream
    stream.Duplex.call @, objectMode: true

    @parser = new StyxParser (msg) =>
        @push msg
    @encoder = new StyxEncoder()
    target.pipe @parser
    @encoder.pipe target

    @on "finish", =>
        @encoder.end()
    @parser.on "finish", =>
        @encoder.end()
        @push null

    return

util.inherits StyxStream, stream.Duplex

StyxStream::_read = (size) ->
    # do nothing, read is async

StyxStream::_write = (chunk, encoding, callback) ->
    @encoder.encode chunk
    callback()