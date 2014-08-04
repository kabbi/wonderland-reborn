styx = require "node-styx"
util = require "util"
rufus = require "rufus"
events = require "events"
stream = require "stream"
async = require "async"
pathUtils = require "path"

logger = rufus.getLogger "styx-client.client"

#
# Our main styx client class
#

StyxClient = module.exports = (@stream, @config) ->
    return new StyxClient() unless @ instanceof StyxClient
    events.EventEmitter.call @

    # Configuration
    @config = @config or {}
    @config.userName ?= process.env.USER

    # Start a styx protocol
    @stream = new styx.StyxStream @stream
    @stream.on "error", (err) ->
        logger.error "Stream error: ", err
        @emit "error", "Stream error: #{err}"

    # Answers map
    @awaitingTags = {}
    @lastTag = 0

    # Answering logic
    @stream.on "data", (msg) =>
        @handleMessage msg

    # Fid management
    @fidMap = {}
    @lastFid = 0

    # Path management
    @currentDir = "/"

    # Start proto
    @mainFid = @createFid()
    @currentFid = styx.NO_FID
    async.waterfall [
        (callback) =>
            @sendMessage {
                type: "Tversion"
                messageSize: 8192
                protocol: "9P2000"
                tag: styx.NO_TAG
            }, callback
        (answer, callback) =>
            callback "unsupported protocol" unless answer.protocol is styx.VERSION
            @maxMessageSize = answer.messageSize
            @sendMessage {
                type: "Tattach"
                fid: @mainFid
                authFid: styx.NO_FID
                userName: @config.userName
                authName: @config.userName
            }, callback
        (answer, callback) =>
            @fidMap[@mainFid].qid = answer.qid
            @currentFid = @cloneFid @mainFid, callback

    ], (err, result) =>
        logger.debug "Finished attach: #{JSON.stringify result}"
        @emit "attached"

    return

util.inherits StyxClient, events.EventEmitter

# Open a file by path. Returns numeric fd
StyxClient::open = (path, mode, callback) ->
    ourFid = styx.NO_FID
    async.waterfall [
        (callback) =>
            @obtainFidForPath path, callback
        (fid, callback) =>
            ourFid = fid
            @sendMessage {
                type: "Topen"
                fid: ourFid
                mode: @parseMode mode
            }, callback
    ], (err, answer) =>
        return callback err if err
        @fidMap[ourFid].ioUnit = answer.ioUnit
        callback null, ourFid

# File i/o functions
StyxClient::write = (fd, buffer, offset, length, position, callback) ->
    @sendMessage {
        type: "Twrite"
        fid: fd
        offset: position
        data: buffer.slice offset length
    }, (err, answer) =>
        callback err, answer?.count, buffer
StyxClient::read = (fd, buffer, offset, length, position, callback) ->
    @sendMessage {
        type: "Tread"
        fid: fd
        offset: position
        count: length
    }, (err, answer) =>
        return callback err if err
        answer.data.copy buffer, offset
        callback null, answer.data.length, buffer

# Stats functions
StyxClient::fstat = (fd, callback) ->
    @sendMessage {
        type: "Tstat"
        fid: fd
    }, (err, answer) ->
        delete answer.type
        delete answer.tag
        callback err, answer
StyxClient::stat = (path, callback) ->
    @obtainFidForPath path, (err, fid) =>
        return callback err if err
        @fstat fid, callback

# Dir reading
StyxClient::readdir = (path, callback) ->
    @createReadStream path, {}, (err, stream) =>
        return callback err if err
        entries = []
        dirParser = new styx.StyxDirParser (stat) ->
            entries.push stat.name
        stream.pipe dirParser
        stream.on "end", ->
            callback null, entries

# Create a readable stream out of file
StyxClient::createReadStream = (path, options, callback) ->
    @open path, options.flags or "", (err, fid) =>
        return callback err if err
        callback null, new StyxFileReadableStream fid, @

# Read all the file contents
StyxClient::readFile = (path, mode, callback) ->
    @createReadStream path, mode, (err, stream) =>
        buffers = []
        stream.on "data", (chunk) ->
            buffers.push chunk
        stream.on "end", ->
            callback null, Buffer.concat buffers

# Change the current dir
StyxClient::chdir = (path, callback) ->
    newCurrentFid = styx.NO_FID
    async.waterfall [
        (callback) =>
            @obtainFidForPath path, callback
        (fid, callback) =>
            @clunkFid @currentFid, callback
            newCurrentFid = fid
    ], (err) =>
        return callback err if err
        @currentFid = newCurrentFid
        callback err

StyxClient::sendMessage = (msg, callback) ->
    msg.tag ?= @lastTag++
    
    @awaitingTags[msg.tag] = (answer) ->
        expectedAnswer = "R" + msg.type[1..]
        if answer.type is "Rerror"
            logger.error "Styx: got Rerror: #{answer.message}"
            callback answer.message
        else if answer.type isnt expectedAnswer
            logger.error "Styx: got #{answer.type}, but expected #{expectedAnswer}"
            callback "rpc bad answer"
        else
            logger.debug "Got #{JSON.stringify answer}"
            callback null, answer

    logger.debug "Sending #{JSON.stringify msg}"
    @stream.write msg

StyxClient::handleMessage = (msg) ->
    @awaitingTags[msg.tag]? msg

# Close the client gracefully
StyxClient::close = (callback) ->
    # TODO: clunk all fids, close opened files, close stream
    fids = (k for own k, v of @fidMap)
    async.eachSeries fids, ((fid, callback) =>
        @clunkFid fid, callback
    ), (err) =>
        return callback err if err
        @stream.end()
        callback?()

# Private methods
StyxClient::clunkFid = (fid, callback) ->
    @removeFid fid
    @sendMessage {
        type: "Tclunk"
        fid: fid
    }, callback

StyxClient::obtainFidForPath = (path, callback) ->
    ourFid = 0
    baseFid = @currentFid
    pathEntries = path.split pathUtils.sep

    # Handle absolute path
    if pathEntries[0] is ""
        baseFid = @mainFid
        pathEntries = pathEntries[1..]
    # Dot isn't used in styx
    pathEntries = pathEntries.filter (entry) -> entry isnt "."

    # Clone base fid and walk it
    async.waterfall [
        (callback) =>
            ourFid = @cloneFid baseFid, callback
        (answer, callback) =>
            @sendMessage {
                type: "Twalk"
                fid: ourFid
                newFid: ourFid
                pathEntries: pathEntries
            }, callback
    ], (err, answer) =>
        callback err, ourFid

StyxClient::cloneFid = (fid, callback) ->
    newFid = @createFid()
    @sendMessage {
        type: "Twalk"
        fid: fid
        newFid: newFid
        pathEntries: []
    }, callback
    return newFid

StyxClient::createFid = () ->
    # TODO: better fid logic, reuse unused
    fid = @lastFid++
    fid++ while @fidMap[fid]?
    @fidMap[fid] = {
        number: fid
        qid: null
        data: null
        ioUnit: 0
    }
    return fid

StyxClient::removeFid = (fid) ->
    delete @fidMap[fid]

StyxClient::parseMode = (mode) ->
    # TODO: implement
    # currently only read
    styx.MODE_READ

#
# Helper stream definitions
#

# Styx file read stream, that wraps styx protocol
StyxFileReadableStream = (@fid, @styxClient) ->
    return new StyxFileReadableStream() unless @ instanceof StyxFileReadableStream
    stream.Readable.call @
    @currentlyReading = false
    @ioUnit = @styxClient.fidMap[@fid].ioUnit
    @offset = 0

util.inherits StyxFileReadableStream, stream.Readable

StyxFileReadableStream::startReading = (size) ->
    return if @currentlyReading
    @currentlyReading = true
    async.doWhilst ( (callback) =>
        @styxClient.sendMessage {
            type: "Tread"
            fid: @fid
            offset: @offset
            count: Math.min size, @ioUnit
        }, (err, answer) =>
            return callback err if err

            # Handle eof
            if not answer.data.length
                @push null
                @currentlyReading = false
                return callback()

            # Handle content reading
            @currentlyReading = @push answer.data
            @offset += answer.data.length
            callback()
    ), (=> @currentlyReading), (->)

StyxFileReadableStream::_read = (size) ->
    @startReading size