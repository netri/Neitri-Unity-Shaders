# [Example World](https://www.vrchat.com/home/launch?worldId=wrld_f4bc450a-6998-4496-bac6-7a53f44dd3ae)

# How it works
The data is stored in render texture, one pixel RGB is world XYZ of the particle.
To render the particles: You take mesh with alot of quads (or you make the quads in tesselation or geometry shader stage), identify every quad for examply by SV_VertexID and move it to positon stored in the texture.
To move the particles: You have a camera that sees only the render texture, and you render the render texture in front of the camera with some special shader that adjusts it's contents, for example it moves every position closer to some point.
You can use the same idea to add velocity or acceleration

.CreateParticlesMesh.cs Was used to create 1 vertex, 512x512 triangle mesh

Unity crashes if you use, ARGB Float render texture on camera that sees something with GrabPass shader.
You can use ARGB Int instead

ARGB Int and HDR to cheat around the need for 2 cameras + render textures is bad
because HDR on ARGB Int internally creates and copies contents into another ARGB Half texture and during the process some bits are discarded
it's essentially 32 bit float to 16 bit half conversion


# Credits
Phi16 - Making the first GPU particles I saw
Mel0n, Des - Showing and explaining me the GPU particles
Merlin, Nave - Optimization tips and ideas
Des - Making avatar held version work
