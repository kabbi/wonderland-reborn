Things to do to make the better Wonderland
==========================================

- Implement all the needed libs (some may be ported, some need to be started from scratch, some may be found in npm repos). So, the list:
    - Reliable udp lib (rudp) 
        - lib
        - tests
        - utils
            - ping
            - speed test
            - benchmarks
            - think of more
    - Styx message packing/unpacking lib
        - lib
            + pack styx messages
            + unpack styx messages
            - some transport utils
            - schema validation for messages
                - use json-schema and tv4 for checks
        - tests
        - utils
            - styxchat
            - styxmon
            - think of more
    - Styx server framework
        - lib
            - several ways to define styx server
                + export host fs
                + some siple struct-like definition
                - consisting of several servers (supporting mounts and unions)
        - tests
        - examples
            - some fs's to expose host resources
                - netfs
                - export (simple export host fs)
                - windowfs or xfs (x server export)
            - pipefs
            - logfs
            - testfs
            - filterfs / overlayfs
    - Some logging framework
        - choose one of these:
            - rufus
            - intel
            - winston
            - maybe others
        - look for some listener support to implement logfs later
    - Some statistics framework. All our projects gather some numeric data, and we need a way to store and analyze it.
        - lib
            - need a way to store and retreive stats
            - automatic runtime analysis (?) (maybe part of cheshire/dht)
        - utils
            - graph plotters (?)

- As for the main project parts, we can define DHT and Cheshire. Cheshire - is the main point of the whole Wonderland, and dht is used as it's transport.
    - DHT: kadoh will be used for the base, modified to support nat overcoming, encryption and more tests for this features. See http://github.com/kabbi/kadoh
        - lib base
            - core kademlia thing
            - some cute optimizations
            - additional rpc support
                - custom user messages
                - more to come
            - nat traversal
            - encryption support
        - tests
            - simple internal per-feature tests
            - some complex thing that starts several servers and interacts somehow
            - some absolutely random tests, including stress-tests
        - utils
            - debug gui
                - nice network visualisation
                - stored data parsing
            - command line client
            - speed test / benchmark
            - dhtfs styx server
    - Cheshire:
        - todo: write these lines when at least some of the above things will be completed

- Some great idea to make Inferno-like emulated OS from js code and styx support. Clarification needed.

- Miscellaneous tools, utils and ideas:
    - GUI styx-based file manager
    - Some documentation tool that will scan our code in realtime and grep 'TODO:' lines 
    - Additional linux/mac/win setup scripts and tools to help mounting styx things
    - Some way or tool to easily install all this libs and node modules