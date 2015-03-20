var KeyboardState = (function() {
  /**
   * - NOTE: it would be quite easy to push event-driven too
   *   - microevent.js for events handling
   *   - in this._onkeyChange, generate a string from the DOM event
   *   - use this as event name
  */
  var KeyboardState  = function()
  {
    // to store the current state
    this.keyCodes  = {};
    this.modifiers  = {};

    // create callback to bind/unbind keyboard events
    var self  = this;
    this._onKeyDown  = function(event){ self._onKeyChange(event, true); };
    this._onKeyUp  = function(event){ self._onKeyChange(event, false);};

    // bind keyEvents
    document.addEventListener("keydown", this._onKeyDown, false);
    document.addEventListener("keyup", this._onKeyUp, false);
  }

  /**
   * To stop listening of the keyboard events
  */
  KeyboardState.prototype.destroy  = function()
  {
    // unbind keyEvents
    document.removeEventListener("keydown", this._onKeyDown, false);
    document.removeEventListener("keyup", this._onKeyUp, false);
  }

  KeyboardState.MODIFIERS  = ['shift', 'ctrl', 'alt', 'meta'];
  KeyboardState.ALIAS  = {
    'left': 37,
    'up': 38,
    'right': 39,
    'down': 40,
    'space': 32,
    'pageup': 33,
    'pagedown': 34,
    'tab': 9
  };

  /**
   * to process the keyboard dom event
  */
  KeyboardState.prototype._onKeyChange  = function(event, pressed)
  {
    // log to debug
    //console.log("onKeyChange", event, pressed, event.keyCode, event.shiftKey, event.ctrlKey, event.altKey, event.metaKey)

    // update this.keyCodes
    var keyCode    = event.keyCode;
    this.keyCodes[keyCode]  = pressed;

    // update this.modifiers
    this.modifiers['shift']= event.shiftKey;
    this.modifiers['ctrl']  = event.ctrlKey;
    this.modifiers['alt']  = event.altKey;
    this.modifiers['meta']  = event.metaKey;
  }

  /**
   * query keyboard state to know if a key is pressed of not
   *
   * @param {String} keyDesc the description of the key. format : modifiers+key e.g shift+A
   * @returns {Boolean} true if the key is pressed, false otherwise
  */
  KeyboardState.prototype.pressed  = function(keyDesc)
  {
    var keys  = keyDesc.split("+");
    for(var i = 0; i < keys.length; i++){
      var key    = keys[i];
      var pressed;
      if(KeyboardState.MODIFIERS.indexOf(key) !== -1){
        pressed  = this.modifiers[key];
      }else if(Object.keys(KeyboardState.ALIAS).indexOf(key) != -1){
        pressed  = this.keyCodes[ KeyboardState.ALIAS[key] ];
      }else {
        pressed  = this.keyCodes[key.toUpperCase().charCodeAt(0)]
      }
      if(!pressed)  return false;
    };
    return true;
  }

  return KeyboardState;
})();


// This source is the javascript needed to build a sky box in **three.js**
// It is the source about this [blog post](/blog/2011/08/15/lets-do-a-sky/).

// Now lets start

// declare a bunch of variable we will need later
var camera, scene, renderer, keyboard, skyBox;

var alpha, beta, gamma;

var events = {
  "mouse": {
    active: false,
    panning: false,
    position: {
      x: 0,
      y: 0
    }
  }
};

// The interval of movement for keyboard movements
var interval = Math.PI / 200;

// When the drift speed is smaller than this number, drifting stops
var driftSpeedCutoff = 0.01;

// The amount that is multipled by the speed every frame that there isn't any
// movement from the mouse
var driftSlowdownRate = 0.90;

// Vertial angle that is cut off from exceeding
var verticalAngleCutOff = Math.PI / 4;

// The direction keys that are mapped
var arrowDirections = ["left", "right", "up", "down", "w", "a", "s", "d"];

function initEventHandlers() {
  // Create the keyboard monitor
  keyboard = new KeyboardState();

  // Setup handlers for all the arrow direction id's if they exist
  arrowDirections.forEach(function(direction) {
    var directionElement = document.getElementById(direction);

    events[direction] = false;

    if (directionElement) {
      directionElement.addEventListener("mousedown", function() {
        events[direction] = true;
      });

      directionElement.addEventListener("click", function(e) {
        e.preventDefault();
      });

      directionElement.addEventListener("mouseup", function() {
        events[direction] = false;
      });
    }
  });

  document.addEventListener("mouseup", function() {
    arrowDirections.forEach(function(direction) {
      events[direction] = false;
    });

    events["mouse"].active = false;

    document.body.style.cursor = "auto";
  });

  document.addEventListener('mousemove', function(event) {
    if (events["mouse"].active) {
      events["mouse"].position.x = event.movementX;
      events["mouse"].position.y = event.movementY;
    }
  });

  renderer.domElement.addEventListener("mousedown", function() {
    events["mouse"].active = true;
    events["mouse"].panning = true;

    document.body.style.cursor = "move";
  });

  // when the window is resized, we need to change our camera and renderer
  window.addEventListener('resize', onWindowResize, false);

  var degToRad = function(degrees) {
    return degrees * Math.PI / 180;
  }

  var deviceOrientationChanged = function(event) {
    // Or rotation about Z
    alpha = degToRad(event.alpha);

    // Or rotation about X
    beta = degToRad(event.beta) - Math.PI / 2;

    // Or rotation about Y
    gamma = degToRad(event.gamma);

    document.getElementById("debug").innerHTML = JSON.stringify({alpha: alpha, beta: beta, gamma: gamma}, null, 2);
  }

  // window.ondeviceorientation = _.throttle(deviceOrientationChanged, 300);
}

// Initialize everything
function init(images) {
  // set gyro
  alpha = 0;
  beta = 0;
  gamma = 0;

  // Create the scene
  scene = new THREE.Scene();

  // Create the camera
  camera = new THREE.PerspectiveCamera(70, window.innerWidth / window.innerHeight, 1, 1000);

  // Because we don't rotate in the Z direction, this will be a natural rotation order
  camera.rotation.order = "YXZ";

  // Load them
  var textureCube = THREE.ImageUtils.loadTextureCube(images);

  // init the cube shadder
  var shader = THREE.ShaderLib["cube"];

  // Setup the uniform
  var uniforms = THREE.UniformsUtils.clone(shader.uniforms);
  uniforms['tCube'].value = textureCube;

  // camerate the material
  var material = new THREE.ShaderMaterial({
    fragmentShader: shader.fragmentShader,
    vertexShader: shader.vertexShader,
    uniforms: uniforms,
    side: THREE.BackSide
  });

  // Generate a sphere geometry
  var meshGeometry = new THREE.SphereGeometry(1000, 32, 32);

  // build the skybox Mesh using the texture cube
  skyBox = new THREE.Mesh(meshGeometry, material);

  // and add it to the scene
  scene.add(skyBox);

  // create the container element
  renderer = new THREE.WebGLRenderer({ antialias: true });

  // Set it to match the window
  renderer.setSize(window.innerWidth, window.innerHeight);

  // Add it to the document body
  document.body.appendChild(renderer.domElement);

  // Add event handlers
  initEventHandlers();
}

function onWindowResize() {
  camera.aspect = window.innerWidth / window.innerHeight;
  camera.updateProjectionMatrix();

  renderer.setSize(window.innerWidth, window.innerHeight);
}

// Execute the move in the direction indicated
function move(action) {
  moveObject(action, camera);
}

function moveObject(action, object) {
  moveObjectAt(action, object, interval);

  if (action == "up" || action == "down" || action == "w" || action == "s") {
    correctMovement(object)
  }
}

// Move the object in the direction indicated at the rate indicated as well
function moveObjectAt(action, object, rate) {
  switch (action) {
    case "left":
    case "a":
      object.rotation.y = (object.rotation.y + rate) % (2 * Math.PI);
      break;
    case "right":
    case "d":
      object.rotation.y = (object.rotation.y - rate) % (2 * Math.PI);
      break;
    case "up":
    case "w":
      object.rotation.x = (object.rotation.x + rate) % (2 * Math.PI);
      break;
    case "down":
    case "s":
      object.rotation.x = (object.rotation.x - rate) % (2 * Math.PI);
      break;
    default:
      break;
  }
}

// Correct the over and under rotation to prevent us from going upside down
function correctMovement(object) {
  // If we are going up or down
  if (object.rotation.x < (- verticalAngleCutOff)) {
    object.rotation.x = - verticalAngleCutOff;
  } else if (object.rotation.x > (verticalAngleCutOff)) {
    object.rotation.x = verticalAngleCutOff;
  }
}

// Animate all the camera actions for the mouse
function animateCameraFromMouse() {
  camera.rotation.x += events["mouse"].position.y / 400;
  camera.rotation.y += events["mouse"].position.x / 400;

  correctMovement(camera);

  // Stop drift
  events["mouse"].position.x *= driftSlowdownRate;
  events["mouse"].position.y *= driftSlowdownRate;

  if (!events["mouse"].active &&
      (Math.abs(events["mouse"].position.x) < driftSpeedCutoff) &&
      (Math.abs(events["mouse"].position.y) < driftSpeedCutoff)) {
        events["mouse"].position.x = 0;
        events["mouse"].position.y = 0;

        events["mouse"].panning = false;
  }
}

// Render the scene (called every frame)
function render() {
  // Request this to be re-run
  requestAnimationFrame(render);

  // If we are still panning
  if (events["mouse"].panning) {
    animateCameraFromMouse();
  }

  // If the mouse is not in use
  if (!events["mouse"].active) {
    // Then check buttons + keyboard
    arrowDirections.forEach(function(direction) {
      if (keyboard.pressed(direction) || events[direction]) {
        move(direction);
      }
    });
  }

  // camera.rotation.x = beta;
  // camera.rotation.y = alpha;

  // Actually render the scene
  renderer.render(scene, camera);
}

function run(images) {
  // bootstrap functions
  // initialiaze everything
  init(images);

  // make it move
  render();
}

function runPrefix(prefix) {
  run([
    prefix + '/posx.jpg',
    prefix + '/negx.jpg',
    prefix + '/posy.jpg',
    prefix + '/negy.jpg',
    prefix + '/posz.jpg',
    prefix + '/negz.jpg'
  ]);
}

document.addEventListener("DOMContentLoaded", function(event) {
  // run([
  //   'canary/pos-x.png',
  //   'canary/neg-x.png',
  //   'canary/pos-y.png',
  //   'canary/neg-y.png',
  //   'canary/pos-z.png',
  //   'canary/neg-z.png'
  // ]);

  // run([
  //   'yokohama/pos-x.jpg',
  //   'yokohama/neg-x.jpg',
  //   'yokohama/pos-y.jpg',
  //   'yokohama/neg-y.jpg',
  //   'yokohama/pos-z.jpg',
  //   'yokohama/neg-z.jpg'
  // ]);

  // runPrefix('storforsen');

  // runPrefix('Lycksele2');

  // runPrefix('Fjaderholmarna');

  // runPrefix("GoldenGateBridge");

  runPrefix("SantaMariaDeiMiracoli");
});
