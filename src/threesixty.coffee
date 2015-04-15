class ThreeSixty

  # Global settings
  VerticalAngleCutOff: Math.PI / 4

  DiectionalIncrement: Math.PI / 128

  DriftCutOff: 0.01

  DriftSlowdownRate: 0.90

  # Direction constants
  LEFT: 0
  RIGHT: 1
  UP: 2
  DOWN: 3

  constructor: (box, urls) ->
    @urls = urls
    @box = box

    @directions = [false, false, false, false]

    @mouse =
      active: false
      panning: false
      speed:
        x: 0
        y: 0
        z: 0

    @isRendering = false

    @stats = new Stats()

  start: ->
    # Create the scene
    @initScene =>
      # Add the objects to render
      @initObjects =>
        # Add the renderer
        @initRenderer =>
          # Add the callbacks for management
          @initControls =>
            # Force a render
            @doRender()

            return

          return

        return

      return

    return

  initScene: (cb) =>
    # Init Scene
    @scene = new (THREE.Scene)

    # Init Camera
    @camera = new (THREE.PerspectiveCamera)(70, window.innerWidth / window.innerHeight, 1, 1000)

    # Because we don't rotate in the Z direction, this will be a natural rotation order
    @camera.rotation.order = 'YXZ'

    window.addEventListener 'resize', (() =>
      # Correct the camera's aspect ratio
      @camera.aspect = window.innerWidth / window.innerHeight
      @camera.updateProjectionMatrix()

      # Adjust the renderer size
      @renderer.setSize window.innerWidth, window.innerHeight

      # Re-render this one time
      @doRender()

      # Exit
      return
    ), false

    cb()

  initObjects: (cb) =>
    THREE.ImageUtils.loadTextureCube @urls, null, (texture) =>
      # init the cube shadder
      shader = THREE.ShaderLib['cube']

      # Setup the uniform
      uniforms = THREE.UniformsUtils.clone(shader.uniforms)
      uniforms['tCube'].value = texture

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

      # # Add mapping wireframe
      #
      # material.wireframe = true
      #
      # (() =>
      #   geometry = new (THREE.BoxGeometry)( 999, 999, 999 )
      #
      #   material = new (THREE.MeshBasicMaterial)( { color: 0x00ff00 } )
      #   material.wireframe = true
      #
      #   cube = new (THREE.Mesh)( geometry, material )
      #
      #   cube.position.x = 0
      #   cube.position.y = 0
      #   cube.position.z = 0
      #
      #   @scene.add cube
      # )()

      # and add it to the scene
      @scene.add skyBox

      cb()

  initRenderer: (cb) =>
    @renderer = new (THREE.WebGLRenderer)()
    @renderer.setSize window.innerWidth, window.innerHeight
    @box.appendChild @renderer.domElement

    # Set FPS mode
    @stats.setMode 0

    # Adjust styles
    @stats.domElement.style.position = 'absolute';
    @stats.domElement.style.right = '0px';
    @stats.domElement.style.top = '0px';

    document.body.appendChild @stats.domElement

    cb()

  initControls: (cb) =>
    # Keyboard shortcuts
    document.addEventListener 'keydown', @eventOnKeyDown, false
    document.addEventListener 'keyup', @eventOnKeyUp, false

    # Mouse dragging
    @renderer.domElement.addEventListener 'mousedown', @eventMouseDown, false
    @renderer.domElement.addEventListener 'mousemove', @eventMouseMove, false
    @renderer.domElement.addEventListener 'mouseup', @eventMouseUp, false
    @renderer.domElement.addEventListener 'mouseout', @eventMouseUp, false

    cb()

  eventOnKeyDown: (e) =>
    # Get the direction
    dir = @getDirection e.keyCode

    # If this is a direction key...
    if dir?
      # Perform it's action
      @beginKeyPress dir

      # And finish
      return

  eventOnKeyUp: (e) =>
    # Get the direction
    dir = @getDirection e.keyCode

    # If this is a direction key...
    if dir?
      # Perform it's action
      @endKeyPress dir

      # And finish
      return

  eventMouseDown: (e) =>
    @mouse.active = true
    @mouse.panning = true

    @startRender()

    return

  eventMouseMove: (e) =>
    if @mouse.active
      @mouse.speed.x = e.movementY
      @mouse.speed.y = e.movementX

    return

  eventMouseUp: (e) =>
    @mouse.active = false

    return

  endKeyPress: (direction) =>
    # If we aren't tracking it
    @directions[direction] = false if @directions[direction]

  beginKeyPress: (direction) =>
    # If we already are managing this direction
    if @directions[direction]
      # Then just return
      return

    # Otherwise set it to true
    @directions[direction] = true

    @startRender()

  getDirection: (key) =>
    switch key
      when 37, 65 then ThreeSixty::LEFT
      when 38, 87 then ThreeSixty::UP
      when 39, 68 then ThreeSixty::RIGHT
      when 40, 83 then ThreeSixty::DOWN
      else null

  move: (direction) =>
    switch direction
      when ThreeSixty::LEFT
        @camera.rotation.y = @camera.rotation.y + ThreeSixty::DiectionalIncrement
      when ThreeSixty::UP
        @camera.rotation.x = @camera.rotation.x + ThreeSixty::DiectionalIncrement

        # Overbound corrections
        @boundMovements()
      when ThreeSixty::RIGHT
        @camera.rotation.y = @camera.rotation.y - ThreeSixty::DiectionalIncrement
      when ThreeSixty::DOWN
        @camera.rotation.x = @camera.rotation.x - ThreeSixty::DiectionalIncrement

        # Overbound corrections
        @boundMovements()

    return

  boundMovements: =>
    if @camera.rotation.x > ThreeSixty::VerticalAngleCutOff
      @camera.rotation.x = ThreeSixty::VerticalAngleCutOff
    else if @camera.rotation.x < -ThreeSixty::VerticalAngleCutOff
      @camera.rotation.x = -ThreeSixty::VerticalAngleCutOff

  startRender: =>
    # If it is not rendering...
    if !@isRendering

      # Then mark it as rendering
      @isRendering = true

      # And start the render
      @render()

    return

  processMouseMovements: () =>
    @camera.rotation.x += @mouse.speed.x / 400
    @camera.rotation.y += @mouse.speed.y / 400

    # Stop drift
    @mouse.speed.x *= ThreeSixty::DriftSlowdownRate
    @mouse.speed.y *= ThreeSixty::DriftSlowdownRate
    if !@mouse.active and Math.abs(@mouse.speed.x) < ThreeSixty::driftSpeedCutoff and Math.abs(@mouse.speed.y) < ThreeSixty::driftSpeedCutoff
      # Stop the movement
      @mouse.speed.x = 0
      @mouse.speed.y = 0

      # Stop the panning
      @mouse.panning = false

    # Overbound corrections
    @boundMovements()

  processMovements: () =>
    _.map @directions, (enabled, direction) =>
      @move direction if enabled

    if @mouse.panning
      @processMouseMovements()

    return

  shouldRerender: ->
    # If there are some directions active...
    @mouse.panning or _.some @directions

  doRender: ->
    # Print debug
    document.getElementById('debug').innerHTML = JSON.stringify(@camera.rotation, null, 2)

    # Render the scene
    @renderer.render @scene, @camera

  render: =>
    if @shouldRerender()
      # Request the animation to repeat once more
      requestAnimationFrame ThreeSixty::render.bind(this)

      # Process all the movements
      @processMovements()

      # Start measuring stats
      @stats.begin()

      # Do the render
      @doRender()

      @stats.end()

    else
      # Finished rendering
      @isRendering = false

    return

document.addEventListener 'DOMContentLoaded', ->
  ts = new ThreeSixty document.body, [
    'images/yokohama/pos-x.jpg',
    'images/yokohama/neg-x.jpg',
    'images/yokohama/pos-y.jpg',
    'images/yokohama/neg-y.jpg',
    'images/yokohama/pos-z.jpg',
    'images/yokohama/neg-z.jpg'
  ]

  ts.start()

  return
