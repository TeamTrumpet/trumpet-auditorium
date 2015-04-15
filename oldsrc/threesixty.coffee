class ThreeSixty

  # The interval of movement for keyboard movements
  interval: Math.PI / 200
  # When the drift speed is smaller than this number, drifting stops
  driftSpeedCutoff: 0.01
  # The amount that is multipled by the speed every frame that there isn't any
  # movement from the mouse
  driftSlowdownRate: 0.90
  # Vertial angle that is cut off from exceeding
  verticalAngleCutOff: Math.PI / 4

  # Constant
  twoPI: (2 * Math.PI)

  # The direction keys that are mapped
  arrowDirections: [
    'left'
    'right'
    'up'
    'down'
    'w'
    'a'
    's'
    'd'
  ]

  keyboardAliases:
    'left': 37
    'up': 38
    'right': 39
    'down': 40

  constructor: (images)->
    # This source is the javascript needed to build a sky box in **three.js**
    # It is the source about this [blog post](/blog/2011/08/15/lets-do-a-sky/).
    # Now lets start
    # declare a bunch of variable we will need later
    @camera = undefined
    @scene = undefined

    @renderer = undefined
    @keyboard = undefined

    @alpha = 0
    @beta = 0
    @gamma = 0

    @keys =
      pressed: {}
      active: false

    @events = 'mouse':
      active: false
      panning: false
      position:
        x: 0
        y: 0

    @run images

  initEventHandlers: ->
    # Create the keyboard monitor
    document.addEventListener 'keydown', @onKeyDown, false

    # Setup handlers for all the arrow direction id's if they exist
    @arrowDirections.forEach (direction) =>
      directionElement = document.getElementById(direction)
      @events[direction] = false
      if directionElement
        directionElement.addEventListener 'mousedown', =>
          @events[direction] = true
          return
        directionElement.addEventListener 'click', (e) ->
          e.preventDefault()
          return
        directionElement.addEventListener 'mouseup', =>
          @events[direction] = false
          return
      return
    document.addEventListener 'mouseup', =>
      @arrowDirections.forEach (direction) =>
        @events[direction] = false
        return
      @events['mouse'].active = false
      document.body.style.cursor = 'auto'
      return
    document.addEventListener 'mousemove', (event) =>
      if @events['mouse'].active
        @events['mouse'].position.x = event.movementX
        @events['mouse'].position.y = event.movementY
      return
    @renderer.domElement.addEventListener 'mousedown', =>
      @events['mouse'].active = true
      @events['mouse'].panning = true
      document.body.style.cursor = 'move'
      return
    # when the window is resized, we need to change our camera and renderer
    window.addEventListener 'resize', @onWindowResize, false

    degToRad = (degrees) ->
      degrees * Math.PI / 180

    deviceOrientationChanged = (event) ->
      # Or rotation about Z
      @alpha = degToRad(event.alpha)
      # Or rotation about X
      @beta = degToRad(event.beta) - (Math.PI / 2)
      # Or rotation about Y
      @gamma = degToRad(event.gamma)

      # Set the data to json
      document.getElementById('debug').innerHTML = JSON.stringify({
        alpha: @alpha
        beta: @beta
        gamma: @gamma
      }, null, 2)

      return

    # window.ondeviceorientation = _.throttle(deviceOrientationChanged, 300);
    return

  # Initialize everything

  init: (images) ->
    # Create the scene
    @scene = new (THREE.Scene)

    # Create the camera
    @camera = new (THREE.PerspectiveCamera)(70, window.innerWidth / window.innerHeight, 1, 1000)

    # Because we don't rotate in the Z direction, this will be a natural rotation order
    @camera.rotation.order = 'YXZ'

    # Load them
    THREE.ImageUtils.loadTextureCube(images, null, @onTextureLoad)

  onTextureLoad: (textureCube) =>
    # init the cube shadder
    shader = THREE.ShaderLib['cube']

    # Setup the uniform
    uniforms = THREE.UniformsUtils.clone(shader.uniforms)
    uniforms['tCube'].value = textureCube

    # camerate the material
    material = new (THREE.ShaderMaterial)(
      fragmentShader: shader.fragmentShader
      vertexShader: shader.vertexShader
      uniforms: uniforms
      side: THREE.BackSide)

    # Generate a sphere geometry
    meshGeometry = new (THREE.SphereGeometry)(1000, 32, 32)

    # build the skybox Mesh using the texture cube
    skyBox = new (THREE.Mesh)(meshGeometry, material)

    # and add it to the scene
    @scene.add skyBox

    # create the container element
    @renderer = new (THREE.WebGLRenderer)(antialias: true)

    # Set it to match the window
    @renderer.setSize window.innerWidth, window.innerHeight

    # Add it to the document body
    document.body.appendChild @renderer.domElement

    # Add event handlers
    @initEventHandlers()

    # make it move!
    @render()
    return

  onKeyDown: (event) =>
    # Get the key pressed
    key = event.keyCode
    console.log "onKeyDown: #{key}"
    @keyPressed key

    return

  keyPressed: (key) =>
    # Check if a keyboard key was pressed
    if @camera.keys(ThreeSixty::keyboardAliases).indexOf(key) != -1
      @keys.pressed[key] = true
      @keys.active = true

      @move ThreeSixty::keyboardAliases[key]
    else
      # Check to see if a keyboard direction was pressed
      ThreeSixty::arrowDirections.some (direction) =>
        # If it was pressed
        if direction.toUpperCase().charCodeAt(0) == key
          @keys.pressed[key] = true
          @keys.active = true

          # Move
          @move direction

          # And return true to kill the loop
          return true
    return

  onWindowResize: ->
    @camera.aspect = window.innerWidth / window.innerHeight
    @camera.updateProjectionMatrix()
    @renderer.setSize window.innerWidth, window.innerHeight
    return

  # Execute the move in the direction indicated
  move: (action) ->
    console.log "Moving #{action}"

    @move@camera action, @camera

    @render()
    return

  move@camera: (action, @camera) ->
    @move@cameraAt action, @camera, ThreeSixty::interval
    if action == 'up' or action == 'down' or action == 'w' or action == 's'
      @correctMovement @camera
    return

  clearDebug: ->
    document.getElementById('debug').innerHTML = null
    return

  addDebug: (obj) ->
    document.getElementById('debug').appendChild(document.createTextNode(JSON.stringify(obj, null, 2)))
    return

  # Move the @camera in the direction indicated at the rate indicated as well
  move@cameraAt: (action, @camera, rate) ->
    switch action
      when 'left', 'a'
        @camera.rotation.y = (@camera.rotation.y + rate) % ThreeSixty::twoPI
      when 'right', 'd'
        @camera.rotation.y = (@camera.rotation.y - rate) % ThreeSixty::twoPI
      when 'up', 'w'
        @camera.rotation.x = (@camera.rotation.x + rate) % ThreeSixty::twoPI
      when 'down', 's'
        @camera.rotation.x = (@camera.rotation.x - rate) % ThreeSixty::twoPI
      else
        break

    return

  # Correct the over and under rotation to prevent us from going upside down
  correctMovement: (@camera) ->
    # If we are going up or down
    if @camera.rotation.x < -ThreeSixty::verticalAngleCutOff
      @camera.rotation.x = -ThreeSixty::verticalAngleCutOff
    else if @camera.rotation.x > ThreeSixty::verticalAngleCutOff
      @camera.rotation.x = ThreeSixty::verticalAngleCutOff
    return

  # Animate all the camera actions for the mouse
  animateCameraFromMouse: ->
    xMovement = @events['mouse'].position.y / 400
    yMovement = @events['mouse'].position.x / 400

    console.log "Mouse moving x: #{}"

    @camera.rotation.x += xMovement
    @camera.rotation.y += yMovement

    @correctMovement @camera

    # Stop drift
    @events['mouse'].position.x *= @driftSlowdownRate
    @events['mouse'].position.y *= @driftSlowdownRate
    if !@events['mouse'].active and Math.abs(@events['mouse'].position.x) < @driftSpeedCutoff and Math.abs(@events['mouse'].position.y) < @driftSpeedCutoff
      # Stop the movement
      @events['mouse'].position.x = 0
      @events['mouse'].position.y = 0

      # Stop the panning
      @events['mouse'].panning = false
    return

  # Render the scene (called every frame)
  render: ->
    # Request this to be re-run
    if @events['mouse'].panning
      requestAnimationFrame ThreeSixty::render.bind(this)

    # If we are still panning
    @animateCameraFromMouse()

    # # If the mouse is not in use
    # if !@events['mouse'].active
    #   # Then check buttons + keyboard
    #   @arrowDirections.forEach (direction) =>
    #     if @keyboard.pressed(direction) or @events[direction]
    #       @move direction
    #     return

    # # Set the gyro
    # camera.rotation.x = beta;
    # camera.rotation.y = alpha;

    # # Set the data to json
    # document.getElementById('debug').innerHTML = JSON.stringify(@camera.rotation, null, 2)

    # Actually render the scene
    @renderer.render @scene, @camera

    return

  run: (images) ->
    # bootstrap functions
    # initialiaze everything
    @init images

    return

document.addEventListener 'DOMContentLoaded', ->
  prefixData = (prefix) ->
    [
      'images/' + prefix + '/posx.jpg'
      'images/' + prefix + '/negx.jpg'
      'images/' + prefix + '/posy.jpg'
      'images/' + prefix + '/negy.jpg'
      'images/' + prefix + '/posz.jpg'
      'images/' + prefix + '/negz.jpg'
    ]

  # run([
  #   'images/canary/pos-x.png',
  #   'images/canary/neg-x.png',
  #   'images/canary/pos-y.png',
  #   'images/canary/neg-y.png',
  #   'images/canary/pos-z.png',
  #   'images/canary/neg-z.png'
  # ]);
  # run([
  #   'images/yokohama/pos-x.jpg',
  #   'images/yokohama/neg-x.jpg',
  #   'images/yokohama/pos-y.jpg',
  #   'images/yokohama/neg-y.jpg',
  #   'images/yokohama/pos-z.jpg',
  #   'images/yokohama/neg-z.jpg'
  # ]);
  # runPrefix('storforsen');
  # runPrefix('Lycksele2');
  # runPrefix('Fjaderholmarna');
  # runPrefix("GoldenGateBridge");

  ts = new ThreeSixty prefixData('storforsen')

  return
