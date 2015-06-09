class ThreeSixty

  Scale: 10
  MouseWheelScale: -250

  MaxRotation: Math.PI/9.5

  # Direction constants
  LEFT: 'left'
  RIGHT: 'right'
  UP: 'up'
  DOWN: 'down'
  IN: 'in'
  OUT: 'out'
  RESET: 'reset'

  constructor: (box, urls) ->
    @urls = urls
    @box = box

    @directions = {}

    @grab =
      active: false
      position: new THREE.Vector2()
      raycast:
        old: new THREE.Vector3()
        new: new THREE.Vector3()
      queue: []

    @panTo =
      active: false
      time:
        start: 0
        end: 0
      from:
        rotation:
          x: 0
          y: 0
          z: 0
      to:
        rotation:
          x: 0
          y: 0
          z: 0

    @isRendering = false
    @renderOnce = false

    @compassNeedle = document.getElementById 'compass-direction-icon'

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
    @camera = new (THREE.PerspectiveCamera)(70, window.innerWidth / window.innerHeight, 1, ThreeSixty::Scale * 10)

    @parentObject = new THREE.Object3D()
    @parentObject.rotation.order = 'YXZ'
    @scene.add @parentObject

    @parentObject.add @camera

    @raycaster = new THREE.Raycaster()

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

      # material.wireframe = true

      # Generate a sphere geometry
      meshGeometry = new (THREE.SphereGeometry)(ThreeSixty::Scale, 32, 32)

      # build the skybox Mesh using the texture cube
      @skyBox = new (THREE.Mesh)(meshGeometry, material)

      # and add it to the scene
      @scene.add @skyBox

      cb()

  initRenderer: (cb) =>
    @renderer = new (THREE.WebGLRenderer)()
    @renderer.setSize window.innerWidth, window.innerHeight
    @box.appendChild @renderer.domElement

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
    document.addEventListener 'mousewheel', @eventScroll, false

    mapControls = document.querySelectorAll '[data-map-control]'

    for mapControl in mapControls
      do (mapControl) =>
        direction = mapControl.dataset.mapControl

        mapControl.addEventListener 'click', (e) =>
          e.preventDefault()

          @eventDoDomControl direction

          return

    cb()

  eventDoDomControl: (operation) =>
    @panTo.time.start = (new Date()).getTime()
    @panTo.time.end = @panTo.time.start + 700

    # get the current camera rotation
    fromRotation = @parentObject.rotation.clone()

    @panTo.from.rotation = fromRotation
    @panTo.to.rotation = fromRotation.clone()

    @panTo.from.position = @camera.position.z
    @panTo.to.position = @panTo.from.position

    switch operation
      when ThreeSixty::LEFT
        # move us PI/2 in the +Y direction
        @panTo.to.rotation.y = @panTo.from.rotation.y + Math.PI/2
      when ThreeSixty::RIGHT
        # move us PI/2 in the -Y direction
        @panTo.to.rotation.y = @panTo.from.rotation.y - Math.PI/2
      when ThreeSixty::IN
        @panTo.to.position -= 1
      when ThreeSixty::OUT
        @panTo.to.position += 1
      when ThreeSixty::RESET
        @parentObject.rotation.y = @parentObject.rotation.y % (2 * Math.PI)

        @panTo.to.rotation.x = 0
        @panTo.to.rotation.y = 0
        @panTo.to.position = 0
      else
        console.log "can't do #{operation}"
        return

    @panTo.to.position = @clampPosition(@panTo.to.position)
    @clampRotation(@panTo.to)

    # mark the panning as active
    @panTo.active = true

    # begin the render
    @startRender()

    return

  eventOnKeyDown: (e) =>
    # Get the direction
    dir = @getDirection e.keyCode

    # If this is a direction key...
    if dir?
      e.preventDefault()

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

  eventScroll: (e) =>
    @camera.position.z += e.wheelDelta / ThreeSixty::MouseWheelScale
    @camera.position.z = @clampPosition(@camera.position.z)

    @renderOnce = true
    @startRender()

    e.preventDefault()
    false

  eventMouseDown: (e) =>
    @grab.active = true

    # Start drag-based rotation. We raycast a point on the outer sphere as our reference,
    # based on where the user has clicked. This is stored as @grab.raycast.old.
    # In eventMouseMove, we raycast again, find the new point on the sphere, and calculate
    # the rotation required to rotate the reference point to that location. This
    # rotation is applied to the camera, except for the Z component, which would be very
    # confusing.
    @grab.position.x = ( e.clientX / window.innerWidth ) * 2 - 1;
    @grab.position.y = - ( e.clientY / window.innerHeight ) * 2 + 1;
    @updateMouseRaycast()
    @grab.raycast.old = @grab.raycast.new

    @startRender()

    return

  eventMouseMove: (e) =>
    if @grab.active
      @grab.position.x = ( e.clientX / window.innerWidth ) * 2 - 1;
      @grab.position.y = - ( e.clientY / window.innerHeight ) * 2 + 1;

      @updateMouseRaycast()

      @calculateRaycastAngle()

    return

  eventMouseUp: () =>
    @grab.active = false
    return

  updateMouseRaycast: () =>
    @raycaster.setFromCamera @grab.position, @camera

    raycastPoint = @raycaster.intersectObject(@skyBox)[0]

    @grab.raycast.new = raycastPoint.point.normalize()

    return

  calculateRaycastAngle: () =>
    # find angle between where the mouse ray hits the sphere and where we want it
    # to hit (the spot on the sphere that was originally grabbed).
    qRot = new THREE.Quaternion()
    qRot.setFromUnitVectors @grab.raycast.new, @grab.raycast.old

    # now we rotate the camera so that if we did the ray cast again, we would hit
    # our reference point (where the user grabbed)

    # add the new rotation to our original
    oldRot = new THREE.Quaternion()
    oldRot.setFromEuler @parentObject.rotation

    qRot.multiply oldRot

    eulerOrder = @parentObject.rotation.order
    @parentObject.rotation.setFromQuaternion qRot, eulerOrder

    # now we try to fix up
    @parentObject.rotation.z = 0

    # clamp x rotation (pitch)
    @clampRotation(@parentObject)
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
      when 187 then ThreeSixty::IN
      when 189 then ThreeSixty::OUT
      else false

  move: (direction) =>
    switch direction
      when ThreeSixty::LEFT
        @parentObject.rotation.y += Math.PI / 200
      when ThreeSixty::UP
        @parentObject.rotation.x += Math.PI / 200
      when ThreeSixty::RIGHT
        @parentObject.rotation.y -= Math.PI / 200
      when ThreeSixty::DOWN
        @parentObject.rotation.x -= Math.PI / 200
      when ThreeSixty::IN
        @camera.position.z += ThreeSixty::Scale / -100
      when ThreeSixty::OUT
        @camera.position.z += ThreeSixty::Scale / 100
      else null

    @camera.position.z = @clampPosition(@camera.position.z)
    @clampRotation(@parentObject)

    return

  clampPosition: (position) =>
    if position < ThreeSixty::Scale * -0.4
      ThreeSixty::Scale * -0.4
    else if position > 0
      0
    else
      position

  clampRotation: (object) =>
    if object.rotation.x > ThreeSixty::MaxRotation
      object.rotation.x = ThreeSixty::MaxRotation

    if object.rotation.x < -ThreeSixty::MaxRotation
      object.rotation.x = -ThreeSixty::MaxRotation

    return

  startRender: =>
    # If it is not rendering...
    if !@isRendering

      # Then mark it as rendering
      @isRendering = true

      # And start the render
      @render()

    return

  processPanTo: () =>
    Tc = (new Date()).getTime()

    if @parentObject.rotation.y != @panTo.to.rotation.y
      @parentObject.rotation.y = @quadraticEaseInEaseOut(Tc, @panTo.to.rotation.y, @panTo.from.rotation.y)

    if @parentObject.rotation.x != @panTo.to.rotation.x
      @parentObject.rotation.x = @quadraticEaseInEaseOut(Tc, @panTo.to.rotation.x, @panTo.from.rotation.x)

    if @camera.position.z != @panTo.to.position
      @camera.position.z = @quadraticEaseInEaseOut(Tc, @panTo.to.position, @panTo.from.position)

    if Tc >= @panTo.time.end
      @parentObject.rotation.y = @panTo.to.rotation.y
      @parentObject.rotation.x = @panTo.to.rotation.x
      @camera.position.z = @panTo.to.position

      # stop panning
      @panTo.active = false

    return

  quadraticEaseInEaseOut: (Tc, G, B) =>
    # compute time
    t = 2 * (Tc - @panTo.time.start) / (@panTo.time.end - @panTo.time.start)

    if t < 1
      return ((G - B)/2) * t * t + B
    else
      t = t - 1
      return ((B - G)/2) * (t * (t - 2) - 1) + B

  processMovements: () =>
    _.map @directions, (enabled, direction) =>
      @move direction if enabled

    if @panTo.active
      @processPanTo()

    # adjust the rotation of the compass needle
    rotationString = "rotate(#{@parentObject.rotation.y}rad)"
    @compassNeedle.style.webkitTransform = rotationString
    @compassNeedle.style.transform = rotationString

    return

  shouldRerender: =>
    # If there are some directions active...
    @grab.active or _.some(@directions) or @panTo.active or @renderOnce

  doRender: ->
    # Render the scene
    @renderer.render @scene, @camera
    @renderOnce = false

  render: =>
    if @shouldRerender()
      # Request the animation to repeat once more
      requestAnimationFrame ThreeSixty::render.bind(this)

      # Process all the movements
      @processMovements()

      # Do the render
      @doRender()

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
