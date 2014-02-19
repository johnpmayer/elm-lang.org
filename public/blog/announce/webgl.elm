
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
      [ intro
      , triangleGL w <| toFloat mousex
      , meat ]

triangleTriangle : Triangle { point : V3, color : V3 }
triangleTriangle = 
  let a = { point = v3 0 1 0, color = v3 255 121 0 }
      b = { point = v3 0.866 -0.5 0, color = v3 115 210 22 }
      c = { point = v3 -0.866 -0.5 0, color = v3 114 159 207 }
  in (a,b,c)

triangleBuf : Buffer { point : V3, color : V3 }
triangleBuf = bind [triangleTriangle]

triangleVert : Shader { point : V3, color : V3 } { rot : M4x4 } { vcolor : V3 }
triangleVert = [glShader|

attribute vec3 point;
attribute vec3 color;
uniform mat4 rot;
varying vec3 vcolor;

void main() {
  vcolor = color;
  gl_Position = rot * vec4(point, 1.0);
}

|]

triangleFrag : Shader {} {} { vcolor : V3 }
triangleFrag = [glShader|

precision mediump float;
varying vec3 vcolor;

void main() {
  gl_FragColor = vec4(vcolor / 256.0, 1.0);
}

|]

triangleProg : Program { point : V3, color : V3 } { rot : M4x4 }
triangleProg = link triangleVert triangleFrag

triangleModel : Float -> Model
triangleModel mousex = encapsulate triangleProg triangleBuf { rot = makeRotate (mousex / 100) (v3 0 0 1) }

triangleGL : Int -> Float -> Element
triangleGL wid mousex = webgl (wid, wid) [triangleModel mousex]

intro = width 600 [markdown|
<style type="text/css">
p { text-align: justify }
pre { background-color: white;
      padding: 10px;
      border: 1px solid rgb(216, 221, 225);
      border-radius: 4px;
}
code > span.kw { color: #268BD2; }
code > span.dt { color: #268BD2; }
code > span.dv, code > span.bn, code > span.fl { color: #D33682; }
code > span.ch { color: #DC322F; }
code > span.st { color: #2AA198; }
code > span.co { color: #93A1A1; }
code > span.ot { color: #A57800; }
code > span.al { color: #CB4B16; font-weight: bold; }
code > span.fu { color: #268BD2; }
code > span.re { }
code > span.er { color: #D30102; font-weight: bold; }
</style>


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

meat = width 600 [markdown|

WebGL in Elm aims to remove the boilerplate from and add some safety to the stock WebGL API. 
The approach manages to retain full control of the graphics processing through shaders while providing compatibility with the Elm-model of managing interactive user interfaces. This release includes a few key features.

* Uses Element similar to collage
* Linear algebra batteries included
* Real GLSL shaders that typecheck!

Compatibility with Signals
--------------------------

The rotating triangle above demonstrates that we can _lift_ our rendering code over signals like the window dimensions and the mouse position. 
If you haven't yet, mouse your mouse around and resize the width of your browser, and notice that the triangle Element reacts automatically.
You can see below the clean separation between pure code and Signal code; this aims to work just like Forms in collage.

``` Haskell
-- Window.width : Signal Int
-- Mouse.x : Signal Int
main : Signal Element
main = lift2 triangleGL Window.width Mouse.x

triangleGL : Int -> Int -> Element
triangleGL wid mousex = 
  let axis = (v3 0 0 1)
      rotation = makeRotate (toFloat mousex / 100) axis
      triangleModel = encapsulate triangleProgram 
                                  triangleBuffer 
                                  { rot = rotation }
  in webgl (wid, wid) [triangleModel mousex]
```

Efficient 3D Transforms
-----------------------

3D graphics is often heavy on linear algebra. This release includes a derivative of the [MJS](https://code.google.com/p/webgl-mjs/) project (MIT License).

MJS provides many utilities to build 3D transforms, including affine transforms to manipulate models, as well as perspective and camera transforms commonly seen in 3D simulations. Here's a small example of the Haskell bindings to MJS.

``` Haskell
myPoint : V3
myPoint = v3 4 7 2

myTransform : M4x4
myTransform = makeTranslate3 1 6 8

myNewPoint : V3
myNewPoint = mul4x4 myTransform myPoint

-- myNewPoint == v3 5 13 10
```


Type-Checkable GLSL
-------------------

It's worth noting that this library does not intend to hide all of the details of WebGL; this library supports arbitrary shaders for direct control over the graphics pipeline using the OpenGL Shading Language, or GLSL! 
A true domain-specific-language, GLSL is excellent at specifying the basic operations of rendering.
You can think of shaders as the pieces of code which are run in parallel on the GPU for each polygon or pixel - shaders tell the GPU how to render your bits. 

The shader below is a vertex shader; it operates on vertices or points in space. 
In this example, each vertex has a position and color, and all vertices in the model share a global rotation transform.
We capture this information by parsing the program source and annotating the type of the shader with records.

``` Haskell
triangleVert : Shader { point : V3, color : V3 } 
                      { rot : M4x4 } 
                      { vcolor : V3 }
triangleVert = [glShader|

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

The next shader is a fragment shader; roughly speaking, once vertices are assigned to pixels, the fragment shaders figures out what each pixel looks like. Notice that, while it has no more information about vertices or global constants, it has information that was passed to it from the above shader, which ran in the previous stage in the pipeline.

``` Haskell
triangleFrag : Shader {} {} { vcolor : V3 }
triangleFrag = [glShader|

precision mediump float;
varying vec3 vcolor;

void main() {
  gl_FragColor = vec4(vcolor / 256.0, 1.0);
}

|\]
```

Including this information in the types of shader literals lets us use the type checker to detect errors at compile time. For instance, we can make sure that we compile programs that comprise of compatible shader parts...

``` Haskell
link : Shader a u v -> Shader {} {} v -> Program a u
link vertShader fragShader = ...
```

... and that, whenever we use a program, we are providing the expected input data.

``` Haskell
encapsulate : Program attr unif -> Buffer attr 
                                -> unif 
                                -> Model
encapsulate : program buffer params = ...
```

|]
