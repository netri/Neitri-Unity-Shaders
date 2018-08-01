# Neitris-Unity-Shaders
Collection of shaders for Unity3D and VRChat.
If anyone feels like throwing some cookies my way: https://www.paypal.me/Neitri


# Shader types

* Shader marked with &#x1F6AA; render what is behind them with some effect, they don't go on your avatar but ideally on some "window" that you will look thru. Post processing might ruin results of these shaders.
* Shader marked with &#x1f4a1; need _CameraDepthTexture, to ensure _CameraDepthTexture is enabled please add a directional Light anywhere to your avatar (idally enabled only when the "window" is enabled) and set it's properties in the following way:<br>
![](https://image.prntscr.com/image/fhYPlY4QTaGga1h2lpX6Og.png)<br>
The settings above should be optimized enough to not cause any additional render passes, if they do, the render passes should be low resolution.
Intensity value has to be over 0, because if it's 0 Unity considers the light as disabled.
You need to do this because Unity's forward rendering _CameraDepthTexture is enabled only if world has at least one light with shadows enabled or if game maker sets
```Camera.main.depthTextureMode = DepthTextureMode.Depth```.

## Wireframe Overlay &#x1F6AA;&#x1f4a1;
Overlays background color on top of original scene.
![](https://image.prntscr.com/image/fnpAeHeITN602TKxwcOMog.png)

## Wireframe Fade &#x1F6AA;&#x1f4a1;
Fades into original scene color.
![](https://image.prntscr.com/image/e7skT9zeTdKK1sSIjC00wA.png)

## World Normal Nice Slow &#x1F6AA;&#x1f4a1;
Slow because it uses two passes instead of one.
![](https://image.prntscr.com/image/C8jEwUwwS4SfFIY2tex16A.png)

## World Normal Ugly Fast &#x1F6AA;&#x1f4a1;
Fast because it uses one pass, ugly because it uses `ddx` and `ddy` which work in 2x2 blocks.
![](https://image.prntscr.com/image/9PsypMDdRIaS1zQwKiiOYg.png)

## World Position &#x1F6AA;&#x1f4a1;
![](https://image.prntscr.com/image/v_BsMeg5SZ6yJeSOzAtjrA.png)

## Censor &#x1F6AA;
Both VR and non VR see same censor squares.<br>
Censor square size decreases as distance to it increases.
![](https://image.prntscr.com/image/bhuRrmypRT62yb8e_cDQAw.png)

# Credits
mel0n - Wireframe shaders idea
Merlin - Wireframe Fade




