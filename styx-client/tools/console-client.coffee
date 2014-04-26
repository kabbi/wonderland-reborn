readline = require "readline"
yargs = require "yargs"
rufus = require "rufus"
net = require "net"

StyxClient = require "../lib/client"

rufus.basicConfig
    level: rufus.INFO
    format: "%message\n"
logger = rufus.getLogger "styx-client.tools.console-client"

argv = yargs.argv
host = argv.host or "localhost"
port = argv.port or 6666

logger.debug "Connecting"
socket = net.connect port, host, ->
    logger.info "Connected to #{host}:#{port}"

    client = new StyxClient socket
    client.on "attached", ->
        rl = readline.createInterface
            input: process.stdin
            output: process.stdout
        rl.setPrompt "styx> "

        commandTable =
            "echo":
                process: (args...) ->
                    logger.info args...
                    rl.prompt()
            "cat":
                process: (path) ->
                    if not path
                        logger.error "No file specified"
                        rl.prompt()
                        return
                    client.createReadStream path, {}, (err, stream) ->
                        return rl.prompt() if err
                        stream.pipe process.stdout
                        stream.on "end", ->
                            rl.prompt()
            "stat":
                process: (path) ->
                    path ?= "."
                    client.stat path, (err, stat) ->
                        return rl.prompt() if err
                        logger.info stat
                        rl.prompt()
            "ls":
                process: (path) ->
                    path ?= "."
                    client.readdir path, (err, files) ->
                        return rl.prompt() if err
                        for file in files
                            logger.info file
                        rl.prompt()
            "cd":
                process: (path) ->
                    path ?= "/"
                    client.chdir path, (err) ->
                        rl.prompt()
            "exit":
                process: ->
                    rl.close()

        rl.on "line", (line) ->
            if not line
                rl.prompt()
                return

            args = line.split " "
            cmd = commandTable[args[0]]

            if not cmd
                logger.error "No such command: #{args[0]}"
                rl.prompt()
                return

            cmd.process args[1..]...

        rl.on "close", ->
            client.close -> process.exit 0

        rl.prompt()

socket.on "end", ->
    logger.info "Disconnected"