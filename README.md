# Neitris-Unity-Shaders
Collection of shaders for Unity3D and VRChat


## Depth buffer based shaders
They render what is behind them with some effect.

In some worlds these shaders may not work correctly, because in Unity's forward rendering _CameraDepthTexture is enabled only if world has at least one light with shadows enabled or if you set 
```Camera.main.depthTextureMode = DepthTextureMode.Depth```.

### Wireframe
![](https://image.prntscr.com/image/fnpAeHeITN602TKxwcOMog.png)

### World Normal Nice Slow
![](https://image.prntscr.com/image/C8jEwUwwS4SfFIY2tex16A.png)

### World Normal Ugly Fast
![](https://image.prntscr.com/image/9PsypMDdRIaS1zQwKiiOYg.png)

### World Position
![](https://image.prntscr.com/image/v_BsMeg5SZ6yJeSOzAtjrA.png)


# Credits
mel0n - wireframe shader idea
