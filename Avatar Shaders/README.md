# About
This shader is tailored for VRChat avatars, it tries to make your anime avatar look just the right good way.

This shader was made with following goals in mind:
- Be noob friendly and easy to setup
- Defaults values are set to ideal battle tested values
- Look acceptably in all scuffed lighting conditions of VRChat worlds
- React to lighting and shadows better than Cubed's
- Be something between Cubed's and Unity's Standard

This is not do it all PBR/Toon comprehensive uber shader like those of Xiexe or Poiyomi.

# Troubleshoting
Some meshes are not visible ? It's faces might be facing wrong direction, try to "Show Advanced" and set Cull: Off.

If your avatar is dark after using normal map, make sure you have this on your model import settings:
![](https://image.prntscr.com/image/XspfVYA_RdKIzu8ZrTVGKQ.png)

# Notes

Cull is Off by default because normal people don't know what culling is.

Rim lighting is missing because it can be simulared with matcaps, there is preset for it.

Shading ramps and matcaps look best with these import settings, we don't want gamma correction to their colors.
![](https://image.prntscr.com/image/4KlO8AB5RlCBtgNKOhiYiw.png)

Ramps should start at black and end in white, use ramp weight to adjust the black color.

Shaders are using Unity's surface shader concept, you can easily adjust them to use metallic or smothness from texture.

Uses ![Disney's BRDF](https://raw.githubusercontent.com/wdas/brdf/master/src/brdfs/disney.brdf).

Color alpha is used only in transparent shader, because that is what people expect.

Subtle barely noticable effects are important too, combinations of many of them have great impact.

# Good concepts/ideas

https://www.scratchapixel.com/lessons/3d-basic-rendering/phong-shader-BRDF

[From mobile to high-end PC: Achieving high quality anime style rendering on Unity](https://www.youtube.com/watch?v=egHSE0dpWRw), [Blog Post](https://blog.naver.com/mnpshino/221541025516)

[The highest peak of Chinese 2D CG! When "miHoYo" of "3rd collapse" uses Unity, it becomes like this](https://chinagamenews.net/market-info-126/), [Video](https://www.youtube.com/watch?v=lrfhA6Grwr0)

https://knarkowicz.wordpress.com/2018/01/04/cloth-shading/
https://knarkowicz.wordpress.com/2014/12/27/analytical-dfg-term-for-ibl/
https://blog.selfshadow.com/publications/s2017-shading-course/drobot/s2017_pbs_multilayered.pdf

