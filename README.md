# Neitris-Unity-Shaders
Collection of shaders for Unity3D and VRChat


## Depth buffer based shaders
They render what is behind them with some effect, they don't go on your avatar but ideally on some "window" that you will look thru.

These shaders need _CameraDepthTexture, to ensure _CameraDepthTexture is enabled please add a directional Light anywhere to your avatar (idally enabled only when the "window" is enabled) and set it's properties in the following way:

![](https://image.prntscr.com/image/fhYPlY4QTaGga1h2lpX6Og.png)

Intensity value has to be over 0, because if it's 0 Unity considers the light as disabled.
You need to do this because Unity's forward rendering _CameraDepthTexture is enabled only if world has at least one light with shadows enabled or if game maker sets
```Camera.main.depthTextureMode = DepthTextureMode.Depth```.



### Wireframe
Post processing might ruin results.

![](https://image.prntscr.com/image/fnpAeHeITN602TKxwcOMog.png)

### World Normal Nice Slow
![](https://image.prntscr.com/image/C8jEwUwwS4SfFIY2tex16A.png)

### World Normal Ugly Fast
![](https://image.prntscr.com/image/9PsypMDdRIaS1zQwKiiOYg.png)

### World Position
![](https://image.prntscr.com/image/v_BsMeg5SZ6yJeSOzAtjrA.png)


# Credits
mel0n - wireframe shader idea
