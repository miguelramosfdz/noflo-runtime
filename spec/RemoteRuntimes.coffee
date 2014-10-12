noflo = require 'noflo'

unless noflo.isBrowser()
  chai = require 'chai' unless chai
  RemoteSubGraph = require '../src/RemoteSubGraph'
  utils = require './utils'
  connection = require '../src/connection'
else
  RemoteSubGraph = require 'noflo-runtime/src/RemoteSubGraph'
  connection = require 'noflo-runtime/src/connection'

# TODO: test the custom ComponentLoader
# TODO: test whole connect/begin/endBracket/disconnect

describe 'Remote runtimes', ->

  describe 'PseudoRuntime over WebSocket in NoFlo', ->

    c = null
    server = null
    port = 3888

    before (done) ->
      if noflo.isBrowser()
        port = 3889
        console.log "WebSocket runtime should have been set up on #{port}"
        done()
      else
        utils.createServer port, (err, s) ->
          server = s
          done()
    after (done) ->
      server.close() if server
      done()

    def =
      label: "NoFlo 222"
      description: "The first remote component in the world"
      type: "noflo"
      protocol: "websocket"
      address: "ws://localhost:#{port}"
      secret: "my-super-secret"
      id: "2ef763ff-1f28-49b8-b58f-5c6a5c23af2d"
      user: "3f3a8187-0931-4611-8963-239c0dff1931"
      seenHoursAgo: 11
    meta = {}
    readyEmitted = false

    it 'should be instantiable', (done) ->
      c = (RemoteSubGraph.getComponentForRuntime def)(meta)
      chai.expect(c).to.be.an.instanceof noflo.Component
      c.on 'ready', () ->
        readyEmitted = true
        done()
    it 'should set description', ->
      chai.expect(c.description).to.equal def.description
    it 'should populate ports and go ready after connecting to remote', (done) ->
      checkPorts = () ->
        chai.expect(c.inPorts.ports).to.be.an 'object'
        chai.expect(c.inPorts.ports["in"]).to.be.an 'object'
        done()
      if readyEmitted
        checkPorts()
      else
        c.on 'ready', () ->
          checkPorts()
    it 'sending data into local port should be echoed back', (done) ->
      input = noflo.internalSocket.createSocket()
      output = noflo.internalSocket.createSocket()
      chai.expect(c.inPorts.in).to.be.an 'object'
      c.inPorts['in'].attach input
      chai.expect(c.outPorts.out).to.be.an 'object'
      c.outPorts.out.attach output

      output.on 'data', (data) ->
        chai.expect(data).to.deep.equal { test: true }
        done()
      input.send {test: true}


  describe 'MicroFlo simulator direct in NoFlo', ->
    c = null
    def =
      label: "MircroFlo sim"
      description: ""
      type: "microflo"
      protocol: "microflo"
      address: "simulator://"
      secret: "my-super-secret2s"
      id: "2ef763ff-1f28-49b8-b58f-5c6a5c23af23"
      user: "3f3a8187-0931-4611-8963-239c0dff1934"
      seenHoursAgo: 11
    forward = """
    INPORT=fOne.IN:INPUT
    OUTPORT=fThree.OUT:OUTPUT
    fOne(Forward) OUT -> IN fTwo(Forward) OUT -> IN fThree(Forward)
    """
    meta = {}
    readyEmitted = false

    before (done) ->
      done()
    after (done) ->
      done()

    it 'should be instantiable', (done) ->
      c = (RemoteSubGraph.getComponentForRuntime def)(meta)
      chai.expect(c).to.be.an.instanceof noflo.Component
      c.once 'ready', () ->
        done()
    it 'should be possible to upload new graph', (done) ->
        checkRunning = (status) ->
          if status.running
            c.runtime.removeListener 'execution', checkRunning
            return done()
        c.runtime.on 'execution', checkRunning
        noflo.graph.loadFBP forward, (graph) ->
          c.runtime.setMain graph # XXX: neccesary/correct?
          connection.sendGraph graph, c.runtime, () ->
            c.runtime.start() # does actual upload, MicroFlo specific
    it 'should have exported inport and outport', (done) ->
      checkPorts = () ->
        chai.expect(c.inPorts.ports).to.be.an 'object'
        chai.expect(c.outPorts.ports).to.be.an 'object'
        chai.expect(c.inPorts.ports['input']).to.be.an 'object'
        chai.expect(c.outPorts.ports['output']).to.be.an 'object'
        done()
      if c.isReady()
        checkPorts()
      else
        c.on 'ready', () ->
          checkPorts()
    it.skip 'sending data into local port should be echoed back', (done) ->
      input = noflo.internalSocket.createSocket()
      output = noflo.internalSocket.createSocket()
      chai.expect(c.inPorts.in).to.be.an 'object'
      c.inPorts['in'].attach input
      chai.expect(c.outPorts.out).to.be.an 'object'
      c.outPorts.out.attach output

      output.on 'data', (data) ->
        chai.expect(data).to.deep.equal { test: true }
        done()
      input.send {test: true}

