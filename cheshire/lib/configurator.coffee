fs = require "fs"
config = require "./config"

fs.mkdirSync "lib" unless fs.existsSync "lib"
fs.mkdirSync "data" unless fs.existsSync "data"

if not fs.existsSync "./data/neighbours.json"
	# Fill in fake neighbours, just to make dht work
	# TODO: try to find transmissions, utorrent, etc peer list and use it
	data = config.dht.fake_peers
	fs.writeFileSync "./data/neighbours.json", JSON.stringify data, null, 4

# FIXME: destroy this awful hack
process.env.KADOH_TRANSPORT = config.dht.transport