{CompositeDisposable} = require 'atom'
{TextEditorView, View} = require 'atom-space-pen-views'
subscriptions = new CompositeDisposable

module.exports =
class BirdwayAtomView
  constructor: () ->
    # Create root element
    @element = document.createElement('div')
    @element.classList.add('birdway-atom')

    input = document.createElement('atom-text-editor')
    input.classList.add('myinput')
    input.setAttribute('mini', true)
    @element.appendChild(input)

    input2 = document.createElement('atom-text-editor')
    input2.classList.add('myinput')
    input2.setAttribute('mini', true)
    @element.appendChild(input2)

    button = document.createElement('button')
    button.textContent = "Click me"
    button.classList.add('mybutton')
    console.log typeof button
    console.log button
    button.onclick = ()->
      button.textContent = "oh no"
    @element.appendChild(button)

    subscriptions.add atom.tooltips.add(button, {title: 'This is a tooltip'})

  # Returns an object that can be retrieved when package is activated
  serialize: ->

  # Tear down any state and detach
  destroy: ->
    @element.remove()

  getElement: ->
    @element
