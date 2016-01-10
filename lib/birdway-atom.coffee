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

  activate: (state) ->
    console.log 'BirdwayAtom was activated!'
    @birdwayAtomView = new BirdwayAtomView(state.birdwayAtomViewState)
    @modalPanel = atom.workspace.addModalPanel(item: @birdwayAtomView.getElement(), visible: false)

    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace', 'birdway-atom:toggle': => @toggle()

  deactivate: ->
    @modalPanel.destroy()
    @subscriptions.dispose()
    @birdwayAtomView.destroy()

  serialize: ->
    birdwayAtomViewState: @birdwayAtomView.serialize()

  toggle: ->
    console.log 'BirdwayAtom was toggled!'
    if @watching == false
      @watching = true
      @socketlog = fs.openSync '/tmp/socketlog', 'w'

      # watch the text change event
      if editor = atom.workspace.getActiveTextEditor()
        if buffer = editor.getBuffer()
          @handler = buffer.onDidChange (diff) =>
            if BirdwayAtom.skip
              console.log "skipped"
              console.log "skip = false"
              BirdwayAtom.skip = false
              return null;
            console.log "change:"
            for k,v of diff
              console.log k + ":" + v
            console.log ""

            jsondata = JSON.stringify diff
            fs.writeSync @socketlog, (jsondata + "\n")
            @sock.write (jsondata + "\n")

      # open the socket to the client
      @sock = new net.Socket()

      @sock.on 'error', (err)=>
        console.log ("socket error: " + err)
        @watching = false
        fs.closeSync @socketlog
        @handler.dispose()

      # @sock.on 'data', (data) =>
      #   console.log data
      carrier.carry(@sock).on 'line', (line)=>
        console.log "got one line:" + line
        try
          diff = JSON.parse line
        catch error
          console.log error
        cBuffer = atom.workspace.getActiveTextEditor().getBuffer()
        console.log "skip = true"
        BirdwayAtom.skip = true
        cBuffer.setTextInRange diff.oldRange, diff.newText


      @sock.connect 9527, '127.0.0.1', ->
        console.log "connected to local client"
    else
      @handler.dispose()
      @watching = false
      @sock.destroy()
      fs.closeSync @socketlog
