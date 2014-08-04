fs = require "fs"
util = require "util"
styx = require "node-styx"
rufus = require "rufus"
async = require "async"
pathUtils = require "path"

{StyxClient} = require "styx-client"

StyxServer = require "./StyxServer"

logger = rufus.getLogger "styx-server.tools.FidBasedStyxServer"

# Some useful constants
# TODO: calculate some real size
STYX_RW_MSG_HEADER_SIZE = 100

# TODO: implementation is not completed
FidBasedStyxServer = module.exports = (@stream, @config) ->
    return new FidBasedStyxServer(stream, config) unless @ instanceof FidBasedStyxServer
    StyxServer.call @, stream, config

    @on "message", (msg) =>
        method = "handle" + msg.type[1].toUpperCase() + msg.type[2..]
        unless @[method]
            logger.warn "Don't know how to handle #{msg.type}" 
            return @answer msg, type: "Rerror", message: styx.EBADARG
        @[method] msg

    # Map of numeric fids to their Fid equivalents
    @fidsMap = {}
    # The root fid, obviously
    @rootFid = @config.rootFid

util.inherits FidBasedStyxServer, StyxServer

FidBasedStyxServer::handleError = (msg, message) ->
    @answer msg, type: "Rerror", message: message

FidBasedStyxServer::validateMessage = (msg) ->
    unless @fidsMap[msg.fid]
        @handleError msg, styx.EBADFID
        return false
    if msg.newFid and msg.newFid isnt msg.fid and @fidsMap[msg.newFid]
        @handleError msg, styx.EINUSE
        return false
    if msg.type in ["Tread", "Twrite"] and not @fidsMap[msg.fid].opened
        @handleError msg, styx.ENOTOPEN
        return false
    true

FidBasedStyxServer::handleVersion = (msg) ->
    @maxMessageSize = msg.messageSize
    @answer msg, type: "Rversion", messageSize: msg.messageSize, protocol: "9P2000"

FidBasedStyxServer::handleAttach = (msg) ->
    @userName = msg.userName
    @answer msg, type: "Rattach", qid: @rootFid.qid
    @fidsMap[msg.fid] = @rootFid

FidBasedStyxServer::handleStat = (msg) ->
    return unless @validateMessage msg
    @fidsMap[msg.fid].stat (err, answer) =>
        return @handleError msg, err unless answer
        answer.type = "Rstat"
        @answer msg, answer

FidBasedStyxServer::handleWalk = (msg) ->
    return unless @validateMessage msg

    # Do a bit of validation
    if "." in msg.pathEntries
        return @handleError msg, styx.EDOT

    @fidsMap[msg.fid].walk msg.pathEntries, (err, newFid, qids) =>
        return @handleError msg, err unless newFid
        @fidsMap[msg.newFid] = newFid
        @answer msg, type: "Rwalk", pathEntries: qids

FidBasedStyxServer::handleClunk = (msg) ->
    return unless @validateMessage msg
    @fidsMap[msg.fid].clunk (err) =>
        return @handleError msg, err if err
        delete @fidsMap[msg.fid]
        @answer msg, type: "Rclunk"

FidBasedStyxServer::handleOpen = (msg) ->
    return unless @validateMessage msg
    @fidsMap[msg.fid].open msg.mode, (err) =>
        return @handleError msg, err if err
        @answer msg, type: "Ropen", qid: @fidsMap[msg.fid].qid, ioUnit: @maxMessageSize - STYX_RW_MSG_HEADER_SIZE

FidBasedStyxServer::handleWrite = (msg) ->
    return unless @validateMessage msg
    @fidsMap[msg.fid].write msg.data, msg.offset, (err, writtenBytes) =>
        return @handleError msg, err if err
        @answer msg, type: "Rwrite", count: writtenBytes

FidBasedStyxServer::handleRead = (msg) ->
    return unless @validateMessage msg
    # Special case for dir reads
    if @fidsMap[msg.fid].qid.type & styx.QID_TYPE_DIR
        return @handleReadDirectiry msg, @fidsMap[msg.fid]
    @fidsMap[msg.fid].read msg.count, msg.offset, (err, data) =>
        return @handleError msg, err unless data
        @answer msg, type: "Rread", data: data

FidBasedStyxServer::handleReadDirectiry = (msg, fid) ->
    # TODO: don't touch internal fid state
    # No seeking except to the beginning or to the end of the previous read
    if fid.readDirCache and msg.offset is 0
        # Clear cache and reset fetched dirs
        logger.debug "Clering dir read cache for fid #{msg.fid}"
        delete fid.readDirCache
        delete fid.lastReadPtr
    if msg.offset isnt 0 and msg.offset isnt fid.lastReadPtr
        return @handleError msg, styx.EOFFSET

    sendDirsAndUpdateCache = (stats, msg) ->
        idx = fid.readDirCache.lastIdx
        buffer = new Buffer 0
        while idx < stats.length
            dir = new styx.StyxEncoder().dir(stats[idx]).result()
            idx++

            if buffer.length + dir.length > msg.count
                # This dir is not fitting
                break

            # Append the dir to the buffer and continue
            # TODO: better buffer management
            newBuffer = new Buffer buffer.length + dir.length
            buffer.copy newBuffer
            dir.copy newBuffer, buffer.length
            # Swap buffers
            buffer = newBuffer

        fid.readDirCache.lastIdx = idx
        fid.lastReadPtr = msg.offset + buffer.length
        @answer msg, type: "Rread", data: buffer

    # Return cache, if we have it
    if fid.readDirCache
        cache = fid.readDirCache
        return sendDirsAndUpdateCache.call @, cache.stats, msg 

    # Else, just fetch all the stats and start the process
    @fidsMap[msg.fid].list (err, stats) =>
        @handleError msg, err unless stats
        fid.readDirCache =
            stats: stats
            lastIdx: 0
        sendDirsAndUpdateCache.call @, stats, msg

# Abstract Fid class, to traverse file trees
FidBasedStyxServer.Fid = () ->
    # The only thing you should provide
    @qid =
        version: 0
        path: 0
        type: 0
    # Emptry constructor
FidBasedStyxServer.Fid::walk = (pathEntries, callback) ->
    # Return the new fid
FidBasedStyxServer.Fid::open = (mode, callback) ->
    # Switch fid to opened state
FidBasedStyxServer.Fid::read = (count, offset, callback) ->
    # Read data slice, return Buffer
FidBasedStyxServer.Fid::write = (data, offset, callback) ->
    # Return the number of bytes written
FidBasedStyxServer.Fid::list = (callback) ->
    # Return the list of stats
FidBasedStyxServer.Fid::stat = (callback) ->
    # Return the stat struct
FidBasedStyxServer.Fid::clunk = (callback) ->
    # Close the fid
