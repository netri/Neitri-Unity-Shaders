

This is the shader I've been using, working on and testing for the last 1 year.<br>
I really like how MMD models look in all the various rendered videos, I've been tring to get close to it.<br>
I want to keep it simple and nice, I will not add as many features as Xiexe's shader has.<br>
If you find world where this shader looks unaccepatable compared to others' please send me the world's name.<br>


This shader was made with the following goals in mind:
- Look natural in all worlds, but be more soft than Unity's standard
- Be something between Cubed's and Unity's Standard
- If everything around you is completely black due to lighting or shadows, you should be completely black too
- React to lighting and shadows better than Cubed's but still retain MMD look
- Switching from Cubed's or Unity's should out of the box be close enough to original look, but more MMD-ish
- Look acceptably in all the various and scuffed lighting conditions of VRChat worlds
- Shader defaults should be set to ideal battle tested values


both "transparent" shaders actually have to be in geometry queue, beause we want them to be shadowed the same as opaque.<br>

ZWrite On is for big geometry such as transparent hair where you want it to occlude it self.<br>
ZWrite Off is for small geometry such as blush which should not occlude anyting.
