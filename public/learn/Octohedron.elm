
import Bitwise (and)
import MJS (V3,v3,toTuple3,add,direction,normalize,scale)
import Graphics.WebGL (Triangle, mapTriangle)
import Website.Skeleton (skeleton)
import Window (dimensions)

port title : String
port title = "Octohedron"

main = skeleton everything <~ dimensions

everything : Int -> Element
everything wid = 
  let w = min 600 wid
  in flow down <| map (width w)
    [ intro
    , asText . map (mapTriangle toTuple3) <| octohedron
    , meat
    , asText . map (mapTriangle showVert) . map addNormals . halfEdgeN 4 <| octohedron
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

Vector Math with MJS
====================

_John P Mayer_

3D graphics programming tends to be heavy on linear algebra. In its most basic manifestion, vector math is used to hold model data and compute tranformations. In theory, this could be done purely in Elm, using tuples, records, or whatever suited the programmer. However, for performance, we included MJS, a high performance linear algrbra library with a focus on providing utilities common to 3D applications.

In this post we'll look at one basic and one advanced use of vector graphics to compute data that can (and will) be used in a 3D application in Elm. In doing so, we will be introduced to some of the basic facilities of vector math in Elm.

The Octohedron
==============

_Not quite 20-sided_

As a big fan of platonic solids, I thought it would be interesting to generate some 3D shapes. 
In Elm, we're going to represent our shapes as lists of triangles or points in three dimensions.
First, some boilerplate. Triangles, by the way, are just a synonym for a 3-tuple.

```Haskell
import Bitwise (and)
import MJS (V3,v3,add,direction,normalize,scale)
import WebGL (Triangle,mapTriangle)

octohedron : [Triangle V3]
```

We're going to clever here and derive each face from the first eight natural numbers.
The coordinate of each vertex of each triangle will be the unit vectors ±i, ±j, and ±k, with the direction determined by the 3 least significant bits of the input number.
It is easy to see that this will generate an octohedron inscribed in the unit circle, with axis-aligned vertices.

```Haskell
octohedron : [Triangle V3]
octohedron = 
  let i = v3 1 0 0
      j = v3 0 1 0
      k = v3 0 0 1
      makeFace : Int -> Triangle V3
      makeFace n = 
        let cx = if (and n 1 == 0) then 1 else -1
            cy = if (and n 2 == 0) then 1 else -1
            cz = if (and n 4 == 0) then 1 else -1
        in (scale i cx, scale j cy, scale k cz)
  in map makeFace [0..7]
```

You'll notice that we use two functions here. 
The first, v3, makes a vector in 3 dimensions, or V3, from three floating point numbers. 
The second, scale, multiplies a vector by a scalar to produce a new vector.
Not much to it!
Below is our generated list of triangles:

|]

meat : Element
meat = [markdown|

more about MJS

```Haskell
midpoint : V3 -> V3 -> V3
midpoint v1 v2 = add v1 <| scale (direction v1 v2) 0.5
```

```Haskell
halfEdge : Triangle V3 -> [Triangle V3]
halfEdge (a,b,c) =
  let ab = normalize <| midpoint a b
      bc = normalize <| midpoint b c
      ca = normalize <| midpoint c a
  in [(a,ab,ca),(b,ab,bc),(c,bc,ca),(ab,bc,ca)] 
```

```Haskell
repeat : (a -> a) -> Int -> a -> a
repeat f n x = foldr (\_ y -> f y) x [0..(n-1)]

halfEdgeN : Int -> [Triangle V3] -> [Triangle V3]
halfEdgeN = repeat (concat . map halfEdge)
```

```Haskell
addNormals : Triangle V3 -> Triangle { pos : V3, norm : V3 }
addNormals (a,b,c) =
  let center = normalize <| scale (add (add a b) c) (1/3)
      addNormal v = { pos = v, norm = center }
  in mapTriangle addNormal (a,b,c)
```

|]

octohedron : [Triangle V3]
octohedron = 
  let i = v3 1 0 0
      j = v3 0 1 0
      k = v3 0 0 1
      makeFace : Int -> Triangle V3
      makeFace n = 
        let cx = if (and n 1 == 0) then 1 else -1
            cy = if (and n 2 == 0) then 1 else -1
            cz = if (and n 4 == 0) then 1 else -1
        in (scale i cx, scale j cy, scale k cz)
  in map makeFace [0..7]

showVert : { pos : V3, norm : V3 } -> String
showVert {pos,norm} = show (toTuple3 pos, toTuple3 norm)

midpoint : V3 -> V3 -> V3
midpoint v1 v2 = add v1 <| scale (direction v1 v2) 0.5

halfEdge : Triangle V3 -> [Triangle V3]
halfEdge (a,b,c) =
  let ab = normalize <| midpoint a b
      bc = normalize <| midpoint b c
      ca = normalize <| midpoint c a
  in [(a,ab,ca),(b,ab,bc),(c,bc,ca),(ab,bc,ca)] 

repeat : (a -> a) -> Int -> a -> a
repeat f n x = foldr (\_ y -> f y) x [0..(n-1)]

halfEdgeN : Int -> [Triangle V3] -> [Triangle V3]
halfEdgeN = repeat (concat . map halfEdge)

addNormals : Triangle V3 -> Triangle { pos : V3, norm : V3 }
addNormals (a,b,c) =
  let center = normalize <| scale (add (add a b) c) (1/3)
      addNormal v = { pos = v, norm = center }
  in mapTriangle addNormal (a,b,c)
