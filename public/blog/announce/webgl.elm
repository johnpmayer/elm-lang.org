
import Website.Skeleton (skeleton)
import open Website.ColorScheme
import Mouse
import Window
import JavaScript as JS

import open MJS
import open Graphics.WebGL

port title : String
port title = "WebGL"

main = skeleton <~ (everything <~ (fst <~ Mouse.position)) ~ Window.dimensions

everything : Int -> Int -> Element
everything mousex wid =
    let w = min 600 wid
    in flow down 
      [ width w intro
      , simpleGL w <| toFloat mousex
      , width w meat ]

simpleTriangle : Triangle { point : V3, color : V3 }
simpleTriangle = 
  let a = { point = v3 0 1 0, color = v3 255 121 0 }
      b = { point = v3 0.866 -0.5 0, color = v3 115 210 22 }
      c = { point = v3 -0.866 -0.5 0, color = v3 114 159 207 }
  in (a,b,c)

simpleBuf : Buffer { point : V3, color : V3 }
simpleBuf = bind [simpleTriangle]

simpleVert : Shader { point : V3, color : V3 } { rot : M4x4 } { vcolor : V3 }
simpleVert = [glShader|

attribute vec3 point;
attribute vec3 color;
uniform mat4 rot;
varying vec3 vcolor;

void main() {
  vcolor = color;
  gl_Position = rot * vec4(point, 1.0);
}

|]

simpleFrag : Shader {} {} { vcolor : V3 }
simpleFrag = [glShader|

precision mediump float;
varying vec3 vcolor;

void main() {
  gl_FragColor = vec4(vcolor / 256.0, 1.0);
}

|]

simpleProg : Program { point : V3, color : V3 } { rot : M4x4 }
simpleProg = link simpleVert simpleFrag

simpleModel : Float -> Model
simpleModel mousex = encapsulate simpleProg simpleBuf { rot = makeRotate (mousex / 100) (v3 0 0 1) }

simpleGL : Int -> Float -> Element
simpleGL wid mousex = webgl (wid, wid) [simpleModel mousex]

intro = [markdown|

WebGL
=====

Satisfying the need for speed
-----------------------------

WebGL is the performance-oriented graphics programming API in Javascript _du jour_. Exposing some of the lowest levels of the graphics pipeline known as OpenGL, WebGL allows programmers maximum detail in their renders at high framerates.

Unfortunately, WebGL features a programming model of an imperative state machine. Simple routines become series of magic incantations; programmers need to concern themselves with the internals of a complicated architechure before anything of interest can be written.

    var pointer = gl.getAttribLocation(program.program, attributeName);
    gl.enableVertexAttribArray(pointer);
    gl.bindBuffer(gl.ARRAY_BUFFER, this.buffer);
    gl.vertexAttribPointer(pointer, this.size, gl.FLOAT, false, 0, 0);

It's no large wonder that libraries like [three.js](http://threejs.org/) are so popular.

This of course skips over other issues like the boilerplate of managing state with the main loop, controlling your graphics application with user inputs via callbacks, and having to write your awesome procedural world generator in JavaScipt. These aren't problems with WebGL itself, but they demonstrate that when it comes to performance web graphics, we might be doing it wrong. 

Can Elm help to make 3D graphics more pleasant?

|]

meat = [markdown|

WebGL in Elm aims to remove the boilerplate from and add some safety to the stock WebGL API. The approach manages to retain full control of the graphics processing through shaders while providing compatibility with the Elm-model of managing interactive user interfaces. This release includes a few key features.

* Real GLSL shaders with extra type information
* An Element that can be lifted using Signal
* A full-featured linear algebra library

It's worth noting that this library does not intend to hide all of the details of WebGL. 

Type-Checkable GLSL
-------------------

WebGL uses the OpenGL Shading Language, or GLSL, for direct control of the graphics pipeline. You can think of shaders as the pieces of code which are run in parallel on the GPU for each pixel. Shaders tell the GPU how to draw your model. GLSL is a domain-specific-language; it is excellent at specifying the basic operations of rendering.

The shader below is a vertex shader; it operates on vertices or points in space. In this example, each vertex has a position and color. All vertices share a global rotation factor, and finally, each vertex will carry another color variable to the other shaders in the program.

We capture this information by parsing the program source and annotating the type of the shader with records.

``` Elm
simpleVert : Shader { point : V3, color : V3 } { rot : M4x4 } { vcolor : V3 }
simpleVert = [glShader|

attribute vec3 point;
attribute vec3 color;
uniform mat4 rot;
varying vec3 vcolor;

void main() {
  vcolor = color;
  gl_Position = rot * vec4(point, 1.0);
}

|\]
```

Enhancing the types of shader literals allows us to leverage the type checker to detect errors at compile time. For instance, we can make sure that we compile programs that comprise of compatible shader parts...

    link : Shader attr unif vary -> Shader {} {} var -> Program attr unif
    link vertShader fragShader = ...

... and that, whenever we use a program, we are providing the expected input data.

    encapsulate : Program attr unif -> Buffer attr -> unif -> Model
    encapsulate : program buffer params = ...

Compatibility with Signals
--------------------------

Nothing in the Graphics.WebGL API deals with Signals. The rotating triangle earlier in the post demonstrates that we can _lift_ our rendering code over signals such as the window dimensions and the mouse position. You can see below the clean separation between pure code and code involving Signals.

```Elm
simpleModel : Float -> Model
simpleModel mousex = 
  let rot = makeRotate (mousex / 100) (v3 0 0 1)
  in encapsulate simpleProg simpleBuf { rot = rot }

simpleGL : Int -> Float -> Element
simpleGL wid mousex = webgl (wid, wid) [simpleModel mousex]

main : Signal Element
main = lift2 simpleGL Window.width Mouse.x
```

Translation, Rotation, and Scaling... Oh My!
--------------------------------------------

3D graphics is often heavy on linear algebra. This release includes a derivative of the [MJS](https://code.google.com/p/webgl-mjs/) project (MIT License).

MJS provides many utilities to build 3D transforms, including affine transforms to manipulate models, as well as perspective and camera transforms commonly seen in 3D simulations. Here's a small example of the Elm bindings to MJS.

```
myPoint : V3
myPoint = v3 4 7 2

myTransform : M4x4
myTransform = makeTranslate3 1 6 8

myNewPoint : V3
myNewPoint = mul4x4 myTransform myPoint

|]
