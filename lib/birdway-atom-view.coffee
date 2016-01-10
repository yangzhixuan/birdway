{CompositeDisposable} = require 'atom'
{TextEditorView, View} = require 'atom-space-pen-views'
Grim = require 'grim'
net = require 'net'
fs = require 'fs'
carrier = require 'carrier'
subscriptions = new CompositeDisposable

module.exports =
class BirdwayAtomView
  skip: false
  watching: false
  marker: null
  cursorColor: ['red', 'blue', 'green', 'yellow']

  constructor: () ->
    # Create root element
    @element = document.createElement('div')
    @element.classList.add('birdway-atom')

    input = document.createElement('atom-text-editor')
    input.classList.add('myinput')
    input.setAttribute('mini', true)
    input.getModel().setText("server address")
    @element.appendChild(input)

    input2 = document.createElement('atom-text-editor')
    input2.classList.add('myinput')
    input2.setAttribute('mini', true)
    input2.getModel().setText("server port")
    @element.appendChild(input2)

    input3 = document.createElement('atom-text-editor')
    input3.classList.add('myinput')
    input3.setAttribute('mini', true)
    input3.getModel().setText("password")
    @element.appendChild(input3)

    @button = document.createElement('button')
    @button.className = "confirm"
    @button.textContent = "connect"
    @button.classList.add('btn')
    @element.appendChild(@button)

    subscriptions.add atom.tooltips.add(@button, {title: 'This is a tooltip'})

    @modalPanel = atom.workspace.addModalPanel(item: @element, visible: false)

    @button.onclick = ()=>
      @start(input.getModel().getText(), parseInt(input2.getModel().getText()),
        input3.getModel().getText())
      @modalPanel.hide()

  toggle: ->
    console.log @modalPanel
    if @modalPanel.isVisible()
      @modalPanel.hide()
    else
      @modalPanel.show()

  # Returns an object that can be retrieved when package is activated
  serialize: ->

  # Tear down any state and detach
  destroy: ->
    @element.remove()
    @modalPanel.destroy()

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

  start: (ip, port, password)->
    console.log 'connecting the server'

    if @watching == false
      @watching = true
      #@socketlog = fs.openSync './socketlog', 'w'

      # watch the text change event
      if editor = atom.workspace.getActiveTextEditor()
        if buffer = editor.getBuffer()
          @handler = buffer.onDidChange (diff) =>
            if @skip
              console.log "skipped"
              console.log "skip = false"
              @skip = false
              return null

            console.log "text change:"
            for k,v of diff
              console.log k + ":" + v
            console.log ""
            jsondata = JSON.stringify diff
            #fs.writeSync @socketlog, (jsondata + "\n")
            @sock.write (jsondata + "\n")

        @handler2 = editor.onDidChangeCursorPosition (diff) =>
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
          @skip = true
          cBuffer.setTextInRange diff.oldRange, diff.newText
        else if diff.newBufferPosition?
          @showCursor diff.newBufferPosition.row, diff.newBufferPosition.column, diff.cursorAtEndOfLine, diff.id

      @sock.connect port, ip, ->
        console.log "connected to local client"
    else
      @handler.dispose()
      @handler2.dispose()
      @watching = false
      @sock.destroy()
      #fs.closeSync @socketlog
