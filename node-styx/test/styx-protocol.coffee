StyxEncoder = require "../styx/encoder"
StyxParser = require "../styx/parser"
handlers = require "../styx/messages"

messages = require "./styx-test-messages"

# TODO: find a way to print debug lines without interfering
# the mocha's output. Current solution only works well with
# 'spec' reporter

describe "Styx", ->
    describe "protocol", ->
        it "should contain valid handler for every message type", () ->
            count = 0
            for key of handlers
                continue unless !isNaN (parseFloat key) and isFinite key
                handler = handlers[key]
                assert.property handler, 'encode'
                assert.property handler, 'decode'
                assert.isFunction handler.encode
                assert.isFunction handler.decode
                count++
            process.stdout.write "got #{count} handlers"

    describe "decode", ->
        it "should decode some test messages", (done) ->

            # Total success count and detailed data
            doneMessages = []
            doneMessagesCount = 0

            for i in [0...messages.length]
                parser = new StyxParser (msg) ->
                    assert.deepEqual msg, messages[i].decoded, "fail decoding #{messages[i].decoded.type}"
                    doneMessages[i] = true

                    if ++doneMessagesCount is messages.length
                        process.stdout.write "tested #{messages.length} messages"
                        do done

                parser.write messages[i].encoded
                doneMessages.push false

            # Check for failures
            setTimeout (->
                for i in [0...doneMessages.length]
                    assert.isTrue doneMessages[i], "timeout decoding #{messages[i].decoded.type}"
                do done
            ), 1000

    describe "encode", ->
        it "should encode some test messages", () ->
            doneMessages = 0
            encoder = new StyxEncoder()
            for i in [0...messages.length]
                result = encoder.encode messages[i].decoded
                assert.deepEqual result, messages[i].encoded, "fail encoding #{messages[i].decoded.type}"
            process.stdout.write "tested #{messages.length} messages"
