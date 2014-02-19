
import Keyboard (arrows)
import MJS (V3,M4x4,v3,mul4x4,makeLookAt,makePerspective,makeRotate,mul)
import Mouse (position)
import Graphics.WebGL (Triangle, zipTriangle, Shader, Program, link, Buffer, bind, Model, encapsulate, webgl)
import Website.Skeleton (skeleton)
import Window (dimensions)

port title : String
port title = "Spinning Box"

main = skeleton <~ (everything <~ livesim) ~ dimensions

everything : Sim -> Int -> Element
everything sim wid = 
  let w = min 600 wid
  in flow down
    [ demo w sim
    , width w <| asText sim.rotX
    , width w <| asText sim.rotY
    , width w <| asText sim.lumens 
    ]

{- Start inputs -}

stepSpin : {x:Int, y:Int} -> { rotX : Float, rotY : Float } -> { rotX : Float, rotY : Float }
stepSpin {x,y} {rotX,rotY} = 
  { rotX = rotX + -0.1 * toFloat y 
  , rotY = rotY + 0.1 * toFloat x }

spin : Signal { rotX : Float, rotY : Float }
spin = foldp stepSpin {rotX=0.5,rotY=0.5} <| sampleOn (fps 25) arrows

sun : Signal V3
sun = 
  let angle = foldp (\_ x -> x + 0.05) 0 <| sampleOn (fps 25) (constant ())
  in lift (\t -> mul4x4 (makeRotate t (v3 0 1 0)) (v3 1 0 0)) angle

stepShade : (Int,Int) -> (Int,Int) -> a -> { a | lumens : Float }
stepShade (mouseX,_) (windowX,_) r = 
  let lumens = toFloat mouseX / toFloat windowX
  in { r | lumens = lumens }

type Sim = { rotX : Float, rotY : Float, lumens : Float, sun : V3 }

livesim : Signal Sim
livesim = lift2 (\a s -> { a | sun = s }) (lift3 stepShade position dimensions spin) sun

{- End inputs -}

{- Start Constants -}

p0 = v3  1  1  1
p1 = v3 -1  1  1
p2 = v3 -1 -1  1
p3 = v3  1 -1  1
p4 = v3  1 -1 -1
p5 = v3  1  1 -1
p6 = v3 -1  1 -1
p7 = v3 -1 -1 -1

front  = [(p0,p1,p2),(p2,p3,p0)]
back   = [(p5,p6,p7),(p7,p4,p5)]
right  = [(p0,p3,p4),(p4,p5,p0)]
left   = [(p1,p2,p7),(p7,p6,p1)]
top    = [(p0,p5,p6),(p6,p1,p0)]
bottom = [(p3,p4,p7),(p7,p2,p3)]

nfront = v3 0 0 1
nback = v3 0 0 -1
nright = v3 1 0 0
nleft = v3 -1 0 0
ntop = v3 0 1 0
nbottom = v3 0 -1 0

positions = front ++ back ++ right ++ left ++ top ++ bottom

gray   = v3 0.7 0.7 0.7
red     = v3 1 0 0
green   = v3 0 1 0
blue    = v3 0 0 1
yellow  = v3 1 1 0
purple  = v3 0 1 1

repeat n elem = map (\_ -> elem) [0..n-1]

colors = concat . map (\c -> repeat 2 (c,c,c)) <| [gray,red,green,blue,yellow,purple]

normals = concat . map (\c -> repeat 2 (c,c,c)) <| [nfront,nback,nright,nleft,ntop,nbottom]

mesh' : [Triangle {pos : V3, color : V3}]
mesh' = zipWith (zipTriangle (\pos color -> { pos = pos, color = color })) positions colors

mesh : [Triangle {pos : V3, color : V3, norm : V3}]
mesh = zipWith (zipTriangle (\poscolor norm -> { poscolor | norm = norm })) mesh' normals

buffer : Buffer {pos : V3, color : V3, norm : V3}
buffer = bind mesh

{- End Constants -}

{- Start Shader -}

type Attribute = { pos : V3, color : V3, norm : V3 }
type Uniform = { per : M4x4, cam : M4x4, rot : M4x4, sun : V3, lumens : Float }
type Varying = { vcolor : V3, vlumens : Float }

vert : Shader Attribute Uniform Varying
vert = [glShader|
attribute vec3 pos;
attribute vec3 color;
attribute vec3 norm;

uniform mat4 per;
uniform mat4 cam;
uniform mat4 rot;
uniform vec3 sun;
uniform float lumens;

varying vec3 vcolor;
varying float vlumens;

void main () {
  gl_Position = per * cam * rot * vec4(pos, 1.0);;
  vcolor = color;
  vec4 modelNorm = rot * vec4(norm, 1.0);
  vlumens = 0.1 + lumens * (0.4 + 0.4 * dot(modelNorm.xyz, sun));
}
|]

frag : Shader {} {} Varying
frag = [glShader|
precision mediump float;
varying vec3 vcolor;
varying float vlumens;
void main () {
  gl_FragColor = vec4(vlumens * vcolor, 1.0);
}
|]

prog : Program Attribute Uniform
prog = link vert frag

{- End Shader -}

{- Start Demo -}

transPerspective : M4x4
transPerspective = makePerspective 45 1 0.01 100

transCamera : M4x4
transCamera = makeLookAt (v3 0 0 5) (v3 0 0 0) (v3 0 1 0)

model : Sim -> Model
model { rotX, rotY, lumens, sun } = 
  let transformRotX = makeRotate rotX <| v3 1 0 0
      transformRotY = makeRotate rotY <| v3 0 1 0
      uniforms = 
        { rot = mul transformRotX transformRotY
        , per = transPerspective
        , cam = transCamera
        , lumens = lumens
        , sun = sun
        }
  in encapsulate prog buffer uniforms

demo : Int -> Sim -> Element
demo wid sim = webgl (wid,wid) [model sim]

{- End Demo -}
