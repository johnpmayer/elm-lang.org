
import Bitwise (and, shiftRight)
import MJS (V3,v3,toTuple3,add,sub,direction,normalize,scale,cross,M4x4,mul,makePerspective,makeLookAt)
import Graphics.WebGL (Triangle, mapTriangle, Shader, Program, link, Buffer, bind, Model, encapsulate, webgl)
import Website.Skeleton (skeleton)
import Window (dimensions)

port title : String
port title = "WebGL Shaders"

main = skeleton everything <~ dimensions

everything : Int -> Element
everything wid = 
  let w = min 600 wid
  in flow down <| map (width w)
    [ intro
    , image w (div (w * 359) 481) "http://1.bp.blogspot.com/-8IL3j4G4fH0/TdjFIM2SILI/AAAAAAAAABs/KUcvpTAXR4E/s1600/webglpipeline.png"
    , meat1
    , render w
    , meat2
    ]

intro : Element
intro = [markdown|

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

WebGL Shaders
=============

_John P Mayer_

WebGL in Elm aims to be as expressive and powerful as WebGL in JavaScript.
Elm programs can use arbitrary shaders and take advantage of low-level performance in a type-safe way.
The graphics pipeline is a good way to start to understant how Elm exposes WebGL.

|]

meat1 : Element
meat1 = [markdown|

To perform a render, there are four major parts to all WebGL programs. These are buffers and uniforms, vertex shaders, and fragment shaders.

Buffers and Uniforms
--------------------

Buffers hold the attribute data. 
In Elm, all of WebGL is done through triangles, and so buffers usually contain things like position of a vertex, the normal vector of a face, or perhaps some other identifying information.
Buffers in Elm are created from lists of triangles, and are polymorphic over the different attributes of the triangles.

```Haskell
bind : [Triangle a] -> Buffer a
```

On the other hand, uniforms are global variables that are constant throughout the duration of a single render. 
They are often used for more "state of the world" type information, rather than being descriptive of the subjects themselves which are being drawn.

The main differentiator between buffers and uniforms is that buffer attributes are per vertex, while uniforms are common for all vertices.

In our example, we're taking our triangles from our [previous post](#), representing our polyhedron, which we'll turn into a Buffer using bind. We'll have a single uniform representing transform of our view, namely, a camera and perspective.

```Haskell
polyhedron : [Triangle { pos : V3, norm : V3 }]

buffer : Buffer { pos : V3, norm : V3 }
buffer = bind polyhedron

uniform : { view : M4x4 }
uniform = 
  let perspective = makePerspective 45 1 0.01 100
      eye = v3 0 0 4
      center = v3 0 0 0
      up = v3 0 1 0
      camera = makeLookAt eye center up
  in { view = mul perspective camera }
```

Vertex Shaders
--------------


Fragment Shaders
----------------


|]

meat2 : Element
meat2 = [markdown|

more text ?

|]

vert : Shader { pos : V3, norm : V3 } { view : M4x4 } { shade : Float }
vert = [glShader|

attribute vec3 pos;
attribute vec3 norm;
uniform mat4 view;
varying float shade;

void main () {
  gl_Position = view * vec4(pos,1.0);
  vec3 light = normalize(vec3(1,2,3));
  shade = dot(norm,light);
  shade = 0.5 + 0.5 * shade;
}

|]

frag : Shader {} {} { shade : Float }
frag = [glShader|

precision mediump float;
varying float shade;

void main () {
  gl_FragColor = vec4(shade * vec3(1.0,1.0,1.0), 1.0);
}

|]

prog : Program { pos : V3, norm : V3 } { view : M4x4 }
prog = link vert frag

buffer : Buffer { pos : V3, norm : V3 }
buffer = bind dochiliatetracontakaioctahedron

uniform : { view : M4x4 }
uniform = 
  let perspective = makePerspective 45 1 0.01 100
      eye = v3 0 0 4
      center = v3 0 0 0
      up = v3 0 1 0
      camera = makeLookAt eye center up
  in { view = mul perspective camera }

model : Model
model = encapsulate prog buffer uniform

render : Int -> Element
render w = webgl (w,w) [model]

octohedron : [Triangle V3]
octohedron = 
  let i = v3 1 0 0
      j = v3 0 1 0
      k = v3 0 0 1
      countBits : Int -> Int -> Int
      countBits c x = case c of
        0 -> 0
        n -> (if (and x 1 == 1) then 1 else 0) + countBits (n-1) (shiftRight x 1)
      makeFace : Int -> Triangle V3
      makeFace n = 
        let cx = if (and n 1 == 0) then 1 else -1
            cy = if (and n 2 == 0) then 1 else -1
            cz = if (and n 4 == 0) then 1 else -1
            counterclockwise = mod (countBits 3 n) 2 == 0
        in if counterclockwise 
           then (scale i cx, scale j cy, scale k cz)
           else (scale i cx, scale k cz, scale j cy)
  in map makeFace [0..7]

showVert : { pos : V3, norm : V3 } -> String
showVert {pos,norm} = show ("pos",toTuple3 pos,"norm",toTuple3 norm)

midpoint : V3 -> V3 -> V3
midpoint v1 v2 = scale (add v1 v2) 0.5

subdivide : Triangle V3 -> [Triangle V3]
subdivide (a,b,c) =
  let ab = normalize <| midpoint a b
      bc = normalize <| midpoint b c
      ca = normalize <| midpoint c a
  in [(a,ab,ca),(b,bc,ab),(c,ca,bc),(ab,bc,ca)] 

repeat : (a -> a) -> Int -> a -> a
repeat f n x = foldr (\_ y -> f y) x [0..(n-1)]

subdivideN : Int -> [Triangle V3] -> [Triangle V3]
subdivideN = repeat (concat . map subdivide)

addNormals : Triangle V3 -> Triangle { pos : V3, norm : V3 }
addNormals (a,b,c) =
  let normal = normalize <| cross (sub b a) (sub c a)
      addNormal v = { pos = v, norm = normal }
  in mapTriangle addNormal (a,b,c)

dochiliatetracontakaioctahedron : [Triangle { pos : V3, norm : V3 }]
dochiliatetracontakaioctahedron = map addNormals . subdivideN 4 <| octohedron
