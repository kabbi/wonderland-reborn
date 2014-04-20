net = require "net"
winston = require "winston"
winston.remove winston.transports.Console
winston.add winston.transports.Console, {colorize: true}
winston.level = 'verbose'
argv = (require "yargs").argv

StyxEncoder = require "../styx/encoder"
StyxParser = require "../styx/parser"

host = argv.host or "localhost"
port = argv.port or 8124

# Connect to some styx server
client = net.connect port, host, ->
    winston.verbose "Connected to #{host}:#{port}"

client.on "end", ->
    winston.verbose "Disconnected"
client.on "error", (error) ->
    winston.error "Some connection exception: #{error}"

# Setup message pipe
encoder = new StyxEncoder()
encoder.pipe client
parser = new StyxParser (msg) ->
    winston.verbose "Got an answer: #{JSON.stringify msg}"
client.pipe parser

# Send all the packets
messages = require "../test/styx-test-messages"
for message in messages
    encoder.encode message.decoded