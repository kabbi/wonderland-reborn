fs = require "fs"
styx = require "node-styx"
util = require "util"
rufus = require "rufus"
events = require "events"
stream = require "stream"
async = require "async"
pathUtils = require "path"

StyxServer = require "./StyxServer"

logger = rufus.getLogger "styx-server.tools.ExportStyxServer"

# Some useful constants
# TODO: calculate some real size
STYX_RW_MSG_HEADER_SIZE = 100

ExportStyxServer = module.exports = (@stream, @config) ->
    return new ExportStyxServer(stream, config) unless @ instanceof ExportStyxServer
    StyxServer.call @, stream, config

    @on "message", (msg) =>
        method = "handle" + msg.type[1].toUpperCase() + msg.type[2..]
        unless @[method]
            logger.warn "Don't know how to handle #{msg.type}" 
            @answer msg, type: "Rerror", message: styx.EBADARG
        @[method]? msg

    # The path we are exporting
    @rootPath = pathUtils.resolve config.exportPath
    # Map of numeric fids to their object equivalents
    @fidsMap = {}
    # Static map to transform styx mode to fs flags
    # TODO: better flags management
    @modeToFlags = {}
    @modeToFlags[styx.MODE_READ] = "r"
    @modeToFlags[styx.MODE_WRITE] = "w"
    @modeToFlags[styx.MODE_READ_WRITE] = "r+"

util.inherits ExportStyxServer, StyxServer

ExportStyxServer::qidTypeByStat = (stat) ->
    # TODO: add more quid types
    if stat.isDirectory() then styx.QID_TYPE_DIR else styx.QID_TYPE_FILE

ExportStyxServer::cloneFid = (fid, newFid) ->
    @fidsMap[newFid] = @fidsMap[fid]
    @fidsMap[newFid].fid = newFid

ExportStyxServer::removeFid = (fid) ->
    delete @fidsMap[fid]

ExportStyxServer::styxStatFromStat = (msg, stat, path) ->
    msg.reservedType = 0
    msg.reservedDev = 0
    msg.qid =
        version: 0
        path: stat.ino
        type: @qidTypeByStat stat
    # TODO: we need or instead of plus here. Add some lib to do bigmath
    msg.mode = stat.mode + if stat.isDirectory() then styx.DMDIR else 0
    msg.lastAccessTime = stat.atime.getTime() // 1000
    msg.lastModificationTime = stat.mtime.getTime() // 1000
    # FIXME: why do we need 0 size for dirs here?
    msg.length = if stat.isDirectory() then 0 else stat.size
    msg.name = pathUtils.basename path
    msg.ownerName = @userName
    msg.groupName = @userName
    msg.lastModifierName = ""
    # Return msg object for convenience
    msg

ExportStyxServer::handleError = (msg, message) ->
    # Handle fs errors
    if message.errno?
        switch message.errno
            when 34
                message = styx.ENOTFOUND
            else
                message = message.code
    @answer msg, type: "Rerror", message: message

ExportStyxServer::obtainQid = (path, callback) ->
    fs.stat path, (err, stat) =>
        return callback err unless stat

        qid =
            version: 0
            path: stat.ino
            type: @qidTypeByStat stat
        callback null, qid

ExportStyxServer::validateMessage = (msg) ->
    unless @fidsMap[msg.fid]
        @handleError msg, styx.EBADFID
        return false
    if msg.newFid and msg.newFid isnt msg.fid and @fidsMap[msg.newFid]
        @handleError msg, styx.EINUSE
        return false
    if msg.type in ["Tread", "Twrite"] and not @fidsMap[msg.fid].fd
        @handleError msg, styx.ENOTOPEN
        return false
    true

ExportStyxServer::handleVersion = (msg) ->
    @maxMessageSize = msg.messageSize
    @answer msg, type: "Rversion", messageSize: msg.messageSize, protocol: "9P2000"

ExportStyxServer::handleAttach = (msg) ->
    @userName = msg.userName
    @fidsMap[msg.fid] =
        fid: msg.fid
        path: @rootPath
    @obtainQid @rootPath, (err, qid) =>
        return @handleError msg, err unless qid
        @answer msg, type: "Rattach", qid: qid
        @fidsMap[msg.fid].qid = qid

ExportStyxServer::handleStat = (msg) ->
    return unless @validateMessage msg
    fs.stat @fidsMap[msg.fid].path, (err, stat) =>
        return @handleError msg, err unless stat
        answerMsg =
            type: "Rstat"
        @styxStatFromStat answerMsg, stat, @fidsMap[msg.fid].path
        @answer msg, answerMsg

ExportStyxServer::handleWalk = (msg) ->
    return unless @validateMessage msg
    # Just copy fid (no path provided)
    unless msg.pathEntries.length
        @answer msg, type: "Rwalk", pathEntries: []
        @cloneFid msg.fid, msg.newFid
        return

    steps = msg.pathEntries
    # Do a bit of validation
    if "." in steps
        return @handleError msg, styx.EDOT
    # Get absolute path for every step
    steps[-1] = @fidsMap[msg.fid].path
    for i in [0...steps.length]
        steps[i] = steps[i - 1] + "/" + steps[i]
    delete steps[-1]
    # Do not allow to walk past export dir boundaries
    for step in steps
        relPath = pathUtils.relative @rootPath, step
        relPath = relPath.split "/"
        return @handleError msg, styx.ENOTFOUND if ".." in relPath
    # Provide qids for every step
    async.map steps, ((path, callback) => @obtainQid path, callback), (err, qids) =>
        return @handleError msg, err if err
        [..., finalPath] = steps
        [..., finalQid] = qids
        @fidsMap[msg.newFid] =
            fid: msg.newFid
            path: finalPath
            qid: finalQid
        @answer msg, type: "Rwalk", pathEntries: qids

ExportStyxServer::handleClunk = (msg) ->
    return unless @validateMessage msg
    @removeFid msg.fid
    @answer msg, type: "Rclunk"

ExportStyxServer::handleOpen = (msg) ->
    return unless @validateMessage msg
    fs.open @fidsMap[msg.fid].path, @modeToFlags[msg.mode], (err, fd) =>
        return @handleError msg, err unless fd
        @fidsMap[msg.fid].fd = fd
        @answer msg, type: "Ropen", qid: @fidsMap[msg.fid].qid, ioUnit: @maxMessageSize - STYX_RW_MSG_HEADER_SIZE

ExportStyxServer::handleWrite = (msg) ->
    return unless @validateMessage msg
    fs.write @fidsMap[msg.fid].fd, msg.data, 0, msg.data.length, msg.offset, (err, written, buffer) =>
        return @handleError msg, err if err
        @answer msg, type: "Rwrite", count: written

ExportStyxServer::handleRead = (msg) ->
    return unless @validateMessage msg
    # Special case for dir reads
    if @fidsMap[msg.fid].qid.type & styx.QID_TYPE_DIR
        return @handleReadDirectiry msg
    # Ordinary reading handling
    fs.read @fidsMap[msg.fid].fd, new Buffer(msg.count), 0, msg.count, msg.offset, (err, bytesRead, buffer) =>
        return @handleError msg, err if err
        # Crop the returned buffer if bytesRead is lower then needed
        buffer = buffer.slice 0, bytesRead unless bytesRead is msg.count
        @answer msg, type: "Rread", data: buffer

ExportStyxServer::handleReadDirectiry = (msg) ->
    # No seeking except to the beginning or to the end of the previous read
    if @fidsMap[msg.fid].readDirCache and msg.offset is 0
        # Clear cache and reset fetched dirs
        logger.debug "Clering dir read cache for fid #{msg.fid}"
        delete @fidsMap[msg.fid].readDirCache
        delete @fidsMap[msg.fid].lastReadPtr
    if msg.offset isnt 0 and msg.offset isnt @fidsMap[msg.fid].lastReadPtr
        return @handleError msg, styx.EOFFSET

    sendDirsAndUpdateCache = (files, stats, msg) ->
        idx = @fidsMap[msg.fid].readDirCache.lastIdx
        buffer = new Buffer 0
        while idx < files.length
            dir = new styx.StyxEncoder().dir(@styxStatFromStat {}, stats[idx], files[idx]).result()
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

        @fidsMap[msg.fid].readDirCache.lastIdx = idx
        @fidsMap[msg.fid].lastReadPtr = msg.offset + buffer.length
        @answer msg, type: "Rread", data: buffer

    # Return cache, if we have it
    if @fidsMap[msg.fid].readDirCache
        cache = @fidsMap[msg.fid].readDirCache
        return sendDirsAndUpdateCache.call @, cache.files, cache.stats, msg 

    # Else, just fetch all the files, stats and start the process
    fs.readdir @fidsMap[msg.fid].path, (err, files) =>
        return @handleError msg, err unless files
        # Transform paths to absolute ones
        files = files.map (file) => @fidsMap[msg.fid].path + "/" + file
        # Get all the stats
        async.map files, fs.stat, (err, stats) =>
            return @handleError msg, err unless files
            @fidsMap[msg.fid].readDirCache =
                stats: stats
                files: files
                lastIdx: 0
            sendDirsAndUpdateCache.call @, files, stats, msg
