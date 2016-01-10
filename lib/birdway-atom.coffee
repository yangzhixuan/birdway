BirdwayAtomView = require './birdway-atom-view'
{CompositeDisposable} = require 'atom'
Grim = require 'grim'
net = require 'net'
fs = require 'fs'
carrier = require 'carrier'

module.exports = BirdwayAtom =
  birdwayAtomView: null
  modalPanel: null
  subscriptions: null
  handler: null
  watching: false
  sock: null
  socketlog: null
  skip: false
  serverOn: false
  marker: null
  cursorColor: ['red', 'blue', 'green', 'yellow']

  activate: (state) ->
    console.log 'BirdwayAtom was activated!'

    @birdwayAtomView = new BirdwayAtomView(state.birdwayAtomViewState)
    @modalPanel = atom.workspace.addModalPanel(item: @birdwayAtomView, visible: false)

    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace', 'birdway-atom:toggle': => @toggle()
    @subscriptions.add atom.commands.add 'atom-workspace', 'birdway-atom:startServer': => @startServer()
    @subscriptions.add atom.commands.add 'atom-workspace', 'birdway-atom:login': => @login()

  deactivate: ->
    @modalPanel.destroy()
    @subscriptions.dispose()
    @birdwayAtomView.destroy()

  serialize: ->
    birdwayAtomViewState: @birdwayAtomView.serialize()

  login: ->
    if @modalPanel.isVisible()
      @modalPanel.hide()
    else
      @modalPanel.show()

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

  test: ->
    #editor = atom.workspace.getActiveTextEditor()
    #editor.insertText('Hello World')
    #console.log editor.getCursorScreenPosition()
    #editor.addCursorAtScreenPosition([0, 2])

    console.log("test now!")
    editor = atom.workspace.getActiveTextEditor()
    range = editor.getSelectedBufferRange() # any range you like
    marker = editor.markBufferRange(range)
    decoration = editor.decorateMarker(marker, {type: 'highlight', class: 'cursorSimulator'})

  showCursor: (line, column, endOfLine, id = 2) ->
    console.log("showing cursor!" + line + " " + column + " " + id)
    if @marker?
      @marker.destroy()
    editor = atom.workspace.getActiveTextEditor()
    # range = editor.getSelectedBufferRange() # any range you like
    if endOfLine == false
      @marker = editor.markBufferRange([[line, column], [line, column + 1]])
      decoration = editor.decorateMarker(@marker, {type: 'highlight', class: @cursorColor[id % 4] + 'CursorSimulator'})
    else
      @marker = editor.markBufferRange([[line, column - 1], [line, column]])
      decoration = editor.decorateMarker(@marker, {type: 'highlight', class: @cursorColor[id % 4] + 'CursorSimulatorAtRight'})

  toggle: ->
    console.log 'BirdwayAtom was toggled!'

    if @watching == false
      @watching = true
      #@socketlog = fs.openSync './socketlog', 'w'

      # watch the text change event
      if editor = atom.workspace.getActiveTextEditor()
        if buffer = editor.getBuffer()
          @handler = buffer.onDidChange (diff) =>
            if BirdwayAtom.skip
              console.log "skipped"
              console.log "skip = false"
              BirdwayAtom.skip = false
              return null

            console.log "text change:"
            for k,v of diff
              console.log k + ":" + v
            console.log ""
            jsondata = JSON.stringify diff
            #fs.writeSync @socketlog, (jsondata + "\n")
            @sock.write (jsondata + "\n")

        handler2 = editor.onDidChangeCursorPosition (diff) =>
          diff.cursorAtEndOfLine = diff.cursor.isAtEndOfLine()
          diff.cursor = undefined
          console.log "cursor change:"
          for k,v of diff
            console.log k + ":" + v
          console.log ""

          jsondata = JSON.stringify diff
          @sock.write (jsondata + "\n")

      # open the socket to the client
      @sock = new net.Socket()

      @sock.on 'error', (err)=>
        console.log ("socket error: " + err)
        @watching = false
        #fs.closeSync @socketlog
        @handler.dispose()

      # @sock.on 'data', (data) =>
      #   console.log data
      carrier.carry(@sock).on 'line', (line)=>
        console.log "got one line:" + line
        try
          diff = JSON.parse line
        catch error
          console.log error
        if diff.oldRange?
          cBuffer = atom.workspace.getActiveTextEditor().getBuffer()
          console.log "skip = true"
          BirdwayAtom.skip = true
          cBuffer.setTextInRange diff.oldRange, diff.newText
        else if diff.newBufferPosition?
          @showCursor diff.newBufferPosition.row, diff.newBufferPosition.column, diff.cursorAtEndOfLine, diff.id

      @sock.connect 9527, '127.0.0.1', ->
        console.log "connected to local client"
    else
      @handler.dispose()
      @watching = false
      @sock.destroy()
      #fs.closeSync @socketlog
