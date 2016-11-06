###
#MP3 streaming server, for nodejs, which streams files over websockets. Requires binaryjs to
#work. At start, you have to provide the mp3 file to stream as the first command
#line argument. Assumes that an ID3v2 tag is present, without extension headers.
#
#Written by Kristian Evensen <kristian.evensen@gmail.com>
###

fs = require 'fs'
bs = require 'binaryjs'
mp3Parser = require "mp3-parser"
BinaryServer = bs.BinaryServer
bss = null
curClient = null

###
#Used for the streaming
###
stream = null
mp3FragmentIdx = 0

###
#This should be the maximum
###
mp3Frames = []
lastFrameIdx = 0
first = true

class Mp3Frame
    constructor: (length) ->
        @mp3FrameBuf = new Buffer length
        @mp3FrameLength = length

startServer = ->
    bss = new BinaryServer {port: 9696}
    bss.on 'connection', clientConnected

mergeAndSendFrames = ->
    console.log "sending frame ", mp3FragmentIdx
    stream.write mp3Frames[mp3FragmentIdx].mp3FrameBuf
    mp3FragmentIdx++

clientConnected = (client) ->
    if curClient != null
        curClient.close()

    curClient = client
    console.log "Client connected, will send first mp3 frame"
    stream = client.createStream()
    stream.on 'drain', streamDrained
    mergeAndSendFrames()

###
#Triggered every time the underlaying socket has drained, i.e., the previous
#buffer has been sent
###
streamDrained = ->
    console.log "drain"
    mergeAndSendFrames()
    ###
    #Remove the listener and notify the server that we are done
    ###
    #stream.removeListener 'drain', streamDrained
    #stream.end()

toArrayBuffer = (buffer) ->
    bufferLength = buffer.length;
    uint8Array = new Uint8Array new ArrayBuffer bufferLength;

    for i in [0...bufferLength]
        uint8Array[i] = buffer[i]
    return uint8Array.buffer

parseMp3File = (err, data) ->
    numFrames = 0

    buffer = new DataView(toArrayBuffer(data))

    tag = mp3Parser.readId3v2Tag(buffer)

    header_size = tag.header.size
    headerIdx = tag._section.byteLength

    console.log "Tag ", JSON.stringify tag
    frameSum = 0

    while headerIdx < data.length
        rawframe = mp3Parser.readFrame(buffer, headerIdx, true)
        if rawframe == null
            rawframe = mp3Parser.readFrame(buffer, headerIdx)
        console.log JSON.stringify rawframe
        #Create the mp3 frame
        frame = new Mp3Frame(rawframe._section.byteLength)
        data.copy frame.mp3FrameBuf, 0, rawframe._section.offset, rawframe._section.offset+rawframe._section.byteLength
        mp3Frames.push(frame)
        
        numFrames++
        headerIdx = rawframe._section.offset+rawframe._section.byteLength

    console.log "File length", data.length
    console.log "HeaderIdx", headerIdx
    console.log "MP3 frames " + numFrames
    console.log "Will start streaming server"
    startServer()

fs.readFile process.argv[2], parseMp3File
