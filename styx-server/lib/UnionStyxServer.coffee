fs = require "fs"
util = require "util"
styx = require "node-styx"
rufus = require "rufus"
async = require "async"
pathUtils = require "path"

{StyxClient} = require "styx-client"

StyxServer = require "./StyxServer"

logger = rufus.getLogger "styx-server.tools.UnionStyxServer"

# Some useful constants
# TODO: calculate some real size
STYX_RW_MSG_HEADER_SIZE = 100

# TODO: implementation is not completed
UnionStyxServer = module.exports = (@stream, @config) ->
    return new UnionStyxServer(stream, config) unless @ instanceof UnionStyxServer
    StyxServer.call @, stream, config

    @on "message", (msg) =>
        # Main routing logic
        if msg.fid? and @foreignFids[msg.fid]?
            union = @foreignFids[msg.fid].union
            # Store the tag and rewrite it
            originalTag = msg.tag
            delete msg.tag

            # TODO: Pre-check walk messages to split them
            continueWalk = null
            if msg.type is "Twalk"
                currentLevel = @foreignFids[msg.fid].level
                for entry, idx in msg.pathEntries
                    currentLevel += if entry is ".." then -1 else 1
                    if currentLevel < 0
                        continueWalk = msg.pathEntries[idx...]
                        msg.pathEntries = msg.pathEntries[...idx]
                        break
            logger.error "Walk intercepted:", msg.pathEntries, "+", continueWalk

            union.client.sendMessage msg, (err, answer) =>
                # Resore tag field
                msg.tag = originalTag
                # Handle errors
                return @handleError msg, err unless answer
                # Track new fid creation on walk success
                if answer.type is "Rwalk"
                    currentLevel = @foreignFids[msg.fid].level
                    for entry in msg.pathEntries
                        currentLevel += if entry is ".." then -1 else 1
                    @foreignFids[msg.newFid] =
                        union: union
                        level: currentLevel
                # Track fid removal
                if answer.type is "Rclunk"
                    delete @foreignFids[msg.fid]
                # Handle splitted walk
                if continueWalk
                    @fidsMap[msg.fid] =
                        fid: msg.fid
                        path: union.path
                        qid: @obtainQid union.path
                    msg.pathEntries = continueWalk
                    # Destroy all the traces on remote side
                    delete @foreignFids[msg.fid]
                    union.client.clunkFid msg.fid, (err, answer) =>
                        return @handleError err unless answer
                        @handleWalk msg, answer.pathEntries
                    return
                @answer msg, answer
            return

        method = "handle" + msg.type[1].toUpperCase() + msg.type[2..]
        unless @[method]
            logger.warn "Don't know how to handle #{msg.type}" 
            return @answer msg, type: "Rerror", message: styx.EBADARG
        @[method] msg

    # Map of numeric fids to their object equivalents
    @fidsMap = {}
    @rootPath = "."
    # Map of mount paths
    @unions = {}
    @unions[@rootPath] =
        children: []
        name: @rootPath
        path: "/"
        leaf: false
        qid: 0
    # Map of fid to unions
    @foreignFids = {}    
    # Next available qid
    @lastQid = 1
    # TODO: make this per-dir
    @dirMode = 0o777

util.inherits UnionStyxServer, StyxServer

#
# Public interface
#

UnionStyxServer::addUnion = (path, stream) ->
    if (path.indexOf "./") isnt 0
        throw Error "bad path argument"

    lastUnion = null
    path = path.split "/"
    for i in [1...path.length]
        name = path[i]
        path[i] = path[i - 1] + "/" + path[i]
        # TODO: use pathUtils.join instead of splits and normalizes
        currentPath = pathUtils.normalize path[i]
        if not @unions[currentPath]
            parent = pathUtils.normalize path[i - 1]
            @unions[parent].children.push name
            @unions[currentPath] ?=
                path: currentPath
                children: []
                name: name
                qid: @lastQid++
        lastUnion = @unions[currentPath]
    lastUnion.leaf = true
    lastUnion.client = new StyxClient stream

UnionStyxServer::removeUnion = (path) ->
    if (path.indexOf "./") isnt 0
        throw Error "bad path argument"
    if not @unions[path]?.leaf
        return

    paths = path.split "/"
    for i in [1...path.length]
        paths[i] = pathUtils.join paths[0..i]
    for path in paths by -1
        delete @unions[path]
        

#
# Styx server implementation
#

UnionStyxServer::cloneFid = (fid, newFid) ->
    @fidsMap[newFid] =
        fid: newFid
        path: @fidsMap[fid].path
        qid: @fidsMap[fid].qid
    newFid

UnionStyxServer::removeFid = (fid) ->
    delete @fidsMap[fid]

UnionStyxServer::styxStatFromStat = (msg, path) ->
    logger.debug "styxStatFromStat", msg, path
    msg.reservedType = 0
    msg.reservedDev = 0
    msg.qid = @obtainQid path
    # TODO: we need 'or' instead of plus here. Add some lib to do bigmath
    msg.mode = styx.DMDIR + @dirMode
    # TODO: make some dynamic times here
    msg.lastAccessTime = 0
    msg.lastModificationTime = 0
    # FIXME: why do we need 0 size for dirs here?
    msg.length = 0
    msg.name = @unions[path].name
    msg.ownerName = @userName
    msg.groupName = @userName
    msg.lastModifierName = ""
    # Return msg object for convenience
    msg

UnionStyxServer::handleError = (msg, message) ->
    @answer msg, type: "Rerror", message: message

UnionStyxServer::obtainQid = (path) ->
    qid =
        version: 0
        path: @unions[path].qid
        type: styx.QID_TYPE_DIR
    qid

UnionStyxServer::validateMessage = (msg) ->
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

UnionStyxServer::handleVersion = (msg) ->
    @maxMessageSize = msg.messageSize
    @answer msg, type: "Rversion", messageSize: msg.messageSize, protocol: "9P2000"

UnionStyxServer::handleAttach = (msg) ->
    @userName = msg.userName
    @fidsMap[msg.fid] =
        fid: msg.fid
        path: @rootPath
    qid = @obtainQid @rootPath
    @answer msg, type: "Rattach", qid: qid
    @fidsMap[msg.fid].qid = qid

UnionStyxServer::handleStat = (msg) ->
    return unless @validateMessage msg
    answerMsg =
        type: "Rstat"
    @styxStatFromStat answerMsg, @fidsMap[msg.fid].path
    @answer msg, answerMsg

UnionStyxServer::handleWalk = (msg, prependQids) ->
    return unless @validateMessage msg
    # Just copy fid (no path provided)
    unless msg.pathEntries.length
        @answer msg, type: "Rwalk", pathEntries: []
        @cloneFid msg.fid, msg.newFid
        return

    # Find out where to put each part of the walk
    destinations = []
    currentDestination =
        pathEntries: []
        union: null
    level = -1
    for step, idx in msg.pathEntries
        path = pathUtils.join @fidsMap[msg.fid].path, msg.pathEntries[..idx]...
        if level >= 0
            level += if step is ".." then -1 else 1
        if level < 0 and currentDestination.union
            destinations.push currentDestination
            currentDestination = 
                pathEntries: []
                union: null
        currentDestination.pathEntries.push step
        if level < 0 and @unions[path].leaf
            if currentDestination.pathEntries.length
                destinations.push currentDestination
                currentDestination = 
                    pathEntries: []
                    union: @unions[path]
            level = 0
    destinations.push currentDestination

    logger.error destinations

    walkQids = []
    handleDestination = (destination, callback) =>
        if destination.union
            client = destination.union.client
            walk = type: "Twalk", fid: client.mainFid, newFid: msg.fid, pathEntries: destination.pathEntries
            client.sendMessage walk, (err, answer) =>
                return callback err unless answer
                walkQids.push answer.pathEntries...
                callback()
        else
            [err, qids] = @handleInternalWalk
                pathEntries: destination.pathEntries
                fid: msg.fid
                newFid: msg.newFid
            return callback err unless qids
            walkQids.push qids...
            process.nextTick callback

    prevDestination = null
    async.eachSeries destinations, ((destination, callback) =>
        if prevDestination?.union
            prevDestination.union.client.clunkFid msg.fid, (err, answer) =>
                return callback err unless answer
                handleDestination destination, callback
                prevDestination = destination
        else
            handleDestination destination, callback
            prevDestination = destination
    ), (err) =>
        return @handleError msg, err if err
        lastUnion = destinations[destinations.length - 1].union
        if lastUnion and lastUnion.leaf
            @foreignFids[msg.newFid] =
                union: lastUnion
                level: 0
        if prependQids
            prependQids.push walkQids...
            walkQids = prependQids
        @answer msg, type: "Rwalk", pathEntries: walkQids

UnionStyxServer::handleInternalWalk = (msg) ->
    # Get absolute path for every step
    steps = msg.pathEntries.map (entry, idx) =>
        pathUtils.join @fidsMap[msg.fid].path, msg.pathEntries[..idx]...
    
    # Provide qids for every step
    qids = []
    for path in steps
        return [styx.ENOTFOUND] unless @unions[path]
        if @unions[path].leaf
            # We need union's root qid, not ours
            client = @unions[path].client
            qids.push client.fidMap[client.mainFid].qid
            break
        qids.push @obtainQid path
    [..., finalPath] = steps
    [..., finalQid] = qids

    # Modify state
    @fidsMap[msg.newFid] =
        fid: msg.newFid
        path: finalPath
        qid: finalQid
    return [null, qids]

UnionStyxServer::handleClunk = (msg) ->
    return unless @validateMessage msg
    @removeFid msg.fid
    @answer msg, type: "Rclunk"

UnionStyxServer::handleOpen = (msg) ->
    return unless @validateMessage msg
    @fidsMap[msg.fid].opened = true
    @answer msg, type: "Ropen", qid: @fidsMap[msg.fid].qid, ioUnit: @maxMessageSize - STYX_RW_MSG_HEADER_SIZE

UnionStyxServer::handleWrite = (msg) ->
    return unless @validateMessage msg
    @handleError msg, styx.EPERM

UnionStyxServer::handleRead = (msg) ->
    return unless @validateMessage msg
    # Special case for dir reads
    if @fidsMap[msg.fid].qid.type & styx.QID_TYPE_DIR
        return @handleReadDirectiry msg, @fidsMap[msg.fid]
    @handleError msg, styx.EPERM

UnionStyxServer::handleReadDirectiry = (msg, fid) ->
    # No seeking except to the beginning or to the end of the previous read
    if fid.readDirCache and msg.offset is 0
        # Clear cache and reset fetched dirs
        logger.debug "Clearing dir read cache for fid #{msg.fid}"
        delete fid.readDirCache
        delete fid.lastReadPtr
    if msg.offset isnt 0 and msg.offset isnt fid.lastReadPtr
        return @handleError msg, styx.EOFFSET

    sendDirsAndUpdateCache = (files, msg) ->
        idx = fid.readDirCache.lastIdx
        buffer = new Buffer 0
        while idx < files.length
            dir = new styx.StyxEncoder().dir(@styxStatFromStat {}, files[idx]).result()
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
        return sendDirsAndUpdateCache.call @, cache.files, msg 

    # Else, just fetch all the files and start the process
    files = @unions[fid.path].children
    # Transform paths to absolute ones
    files = files.map (file) => pathUtils.normalize fid.path + "/" + file

    fid.readDirCache =
        files: files
        lastIdx: 0
    sendDirsAndUpdateCache.call @, files, msg

UnionStyxServer::unionHandleError = (union, message) ->
    # TODO: lock every interaction with failed server

UnionStyxServer::unionWalkInto = (union, msg, pathEntries) ->
    client = union.client
    # Construct the new walk, to obtain the same fid on mounted server
    walk = type: "Twalk", fid: client.mainFid, newFid: msg.newFid, pathEntries: pathEntries
    client.sendMessage walk, (err, answer) =>
        return @unionHandleError union, err unless answer
        # Nothing else to do, we've just ensured that we have new fid
