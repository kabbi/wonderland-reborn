events = require "events"
stream = require "stream"
util = require "util"

PipeStream = (options) ->
    events.EventEmitter.call @

    @upstream = new stream.PassThrough options
    @upstream.on "data", (data) => @emit "data", data
    @upstream.on "error", (err) => @emit "error", err
    @upstream.on "end", () => @emit "end"

    @downstream = new stream.PassThrough options
    @downstream.on "close", () => @emit "close"
    @downstream.on "error", (err) => @emit "error", err
    @downstream.on "drain", () => @emit "drain"

    @pipe = (stream) =>
        @upstream.pipe stream

    @write = (data) =>
        @downstream.write data
    
    @end = () =>
        @downstream.end()

    return

util.inherits PipeStream, events.EventEmitter

module.exports.createPipe = (options) ->
    s1 = new PipeStream options
    s2 = new PipeStream options
    s1.downstream.pipe s2.upstream
    s2.downstream.pipe s1.upstream
    [s1, s2]