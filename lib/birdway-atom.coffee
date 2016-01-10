BirdwayAtomView = require './birdway-atom-view'
{CompositeDisposable} = require 'atom'
Grim = require 'grim'
net = require 'net'
fs = require 'fs'
carrier = require 'carrier'

module.exports = BirdwayAtom =
  serverOn: false

  activate: (state) ->
    console.log 'BirdwayAtom was activated!'

    @birdwayAtomView = new BirdwayAtomView(state.birdwayAtomViewState)

    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace', 'birdway-atom:startServer': => @startServer()
    @subscriptions.add atom.commands.add 'atom-workspace', 'birdway-atom:login': => @login()

  deactivate: ->
    @subscriptions.dispose()
    @birdwayAtomView.destroy()

  serialize: ->
    birdwayAtomViewState: @birdwayAtomView.serialize()

  login: ->
    @birdwayAtomView.toggle()


  startServer: ->
    if @serverOn == false
      @serverOn = true
      clients = []
      svr = net.createServer (sock)->
        console.log "connected: " + sock.remoteAddress + ":" + sock.remotePort
        clients.push sock
        carrier.carry(sock).on 'line', (data)->
          console.log "data: " + sock.remoteAddress + ":" + data
          diff = JSON.parse data
          console.log clients.indexOf(sock)
          console.log diff
          diff.id = 1
          console.log "in server now!!!"
          for k,v of diff
            console.log k + ":" + v
          jsondata = JSON.stringify diff

          for client in clients
            if client != sock
              client.write(jsondata + "\n")
              #client.write(data)

        sock.on 'end', ->
          clients.splice clients.indexOf(sock), 1
      svr.listen({port: 9527})
      console.log "server started!"
