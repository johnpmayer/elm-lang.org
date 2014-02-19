
import Bitwise (and, shiftRight)
import MJS (V3,v3,toTuple3,add,sub,direction,normalize,scale,cross)
import Graphics.WebGL (Triangle, mapTriangle)
import Website.Skeleton (skeleton)
import Window (dimensions)

port title : String
port title = "Octohedron"

main = skeleton everything <~ dimensions

everything : Int -> Element
everything wid = 
  let w = min 600 wid
      showOctogon = map (mapTriangle toTuple3) octohedron
      showSubdivided = map (mapTriangle showVert) dochiliatetracontakaioctahedron
  in flow down <| map (width w)
    [ intro
    , asText showOctogon
    , meat1
    , fittedImage w (div w 3) "http://www.rhythm.com/~ivan/images/dm/trisubdiv.GIF"
    , meat2
    , asText ("Length: " ++ show (length showSubdivided))
    , asText showSubdivided
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
--------------

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
The coordinate of each vertex of each triangle will be the unit vectors ±i, ±j, and ±k, with their respective directions (positive or negative) determined by the 3 least significant bits of the input number.
We also take extra steps to make sure the vertices of each face are counterclockwise from the perspective of outside the solid.
The below code generates an octohedron inscribed in the unit circle, with axis-aligned vertices.

```Haskell
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
```

You'll notice that we use two functions from the MJS library here. 
The first, v3, makes a vector, a V3, from three floating point numbers. 
The second, scale, multiplies a vector by a scalar to produce a new vector.
Not much to it!
Below is our generated list of triangles:

|]

meat1 : Element
meat1 = [markdown|

Triangle Subdivision
--------------------

Our goal in this next section will be to transform our humble octohedron into a polyhedron with 2048 sides.
I'm not completely sure, but I believe that this would be called a *dochiliatetracontakaioctahedron.*
We will obtain this result by dividing each triangle into 4 sub-triangles.

|]

meat2 : Element
meat2 = [markdown|

The algorithm can be described by simply finding the three midpoints of the triangle, and creating the 4 ensuing small triangles.
Note that because Elm values are immutable, we reuse rather than copy the original vertices. 
This should help with memory usage in our representation.
Again, we take care to preserve the counterclockwise order.

```Haskell
midpoint : V3 -> V3 -> V3
midpoint v1 v2 = scale (add v1 v2) 0.5

subdivide : Triangle V3 -> [Triangle V3]
subdivide (a,b,c) =
  let ab = normalize <| midpoint a b
      bc = normalize <| midpoint b c
      ca = normalize <| midpoint c a
  in [(a,ab,ca),(b,bc,ab),(c,ca,bc),(ab,bc,ca)] 
```

To apply the subdivision multiple times, we use these simple helpers.

```Haskell
repeat : (a -> a) -> Int -> a -> a
repeat f n x = foldr (\_ y -> f y) x [0..(n-1)]

subdivideN : Int -> [Triangle V3] -> [Triangle V3]
subdivideN = repeat (concat . map subdivide)
```

Finally, we're going to augment each face with a normal vector.
Because we've been so careful to maintain the counterclockwise order of the vertices,
we simply take the normalized cross product of two "edge" vectors.

```Haskell
addNormals : Triangle V3 -> Triangle { pos : V3, norm : V3 }
addNormals (a,b,c) =
  let normal = normalize <| cross (sub b a) (sub c a)
      addNormal v = { pos = v, norm = normal }
  in mapTriangle addNormal (a,b,c)
```

All of this was computed at page load, and most of that time is likely spent pretty-printing the information.
We'll render the below mesh data using webgl in our [next example](/learn/GLSL.elm).

|]

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
dochiliatetracontakaioctahedron = map addNormals . subdivideN 1 <| octohedron
