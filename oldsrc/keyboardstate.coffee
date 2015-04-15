class KeyboardState

  ###*
  # - NOTE: it would be quite easy to push event-driven too
  #   - microevent.js for events handling
  #   - in this._onkeyChange, generate a string from the DOM event
  #   - use this as event name
  ###
  constructor: ()->
    # to store the current state
    @keyCodes = {}
    @modifiers = {}
    # create callback to bind/unbind keyboard events
    self = this

    @_onKeyDown = (event) ->
      self._onKeyChange event, true
      return

    @_onKeyUp = (event) ->
      self._onKeyChange event, false
      return

    # bind keyEvents
    document.addEventListener 'keydown', @_onKeyDown, false
    document.addEventListener 'keyup', @_onKeyUp, false
    return

  ###*
  # To stop listening of the keyboard events
  ###

  destroy: ->
    # unbind keyEvents
    document.removeEventListener 'keydown', @_onKeyDown, false
    document.removeEventListener 'keyup', @_onKeyUp, false
    return

  MODIFIERS: [
    'shift'
    'ctrl'
    'alt'
    'meta'
  ]
  ALIAS:
    'left': 37
    'up': 38
    'right': 39
    'down': 40
    'space': 32
    'pageup': 33
    'pagedown': 34
    'tab': 9

  ###*
  # to process the keyboard dom event
  ###

  _onKeyChange: (event, pressed) ->
    # log to debug
    #console.log("onKeyChange", event, pressed, event.keyCode, event.shiftKey, event.ctrlKey, event.altKey, event.metaKey)
    # update this.keyCodes
    keyCode = event.keyCode
    @keyCodes[keyCode] = pressed
    # update this.modifiers
    @modifiers['shift'] = event.shiftKey
    @modifiers['ctrl'] = event.ctrlKey
    @modifiers['alt'] = event.altKey
    @modifiers['meta'] = event.metaKey
    return

  ###*
  # query keyboard state to know if a key is pressed of not
  #
  # @param {String} keyDesc the description of the key. format : modifiers+key e.g shift+A
  # @returns {Boolean} true if the key is pressed, false otherwise
  ###

  pressed: (keyDesc) ->
    keys = keyDesc.split('+')
    i = 0
    while i < keys.length
      key = keys[i]
      pressed = undefined
      if @MODIFIERS.indexOf(key) != -1
        pressed = @modifiers[key]
      else if @camera.keys(@ALIAS).indexOf(key) != -1
        pressed = @keyCodes[@ALIAS[key]]
      else
        pressed = @keyCodes[key.toUpperCase().charCodeAt(0)]
      if !pressed
        return false
      i++
    true
