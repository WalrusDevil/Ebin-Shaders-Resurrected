# Ebin Shaders Resurrected

Ebin Shaders is a Minecraft shaderpack for use with the [OptiFine](https://optifine.net/home) and [Iris](https://irisshaders.dev/) mods.

Ebin began with the goal of being fast, beautiful, configurable, feature-rich, and having a base of well-written code. It was developed almost entirely by BruceKnowsHow ([Github](https://github.com/BruceKnowsHow), [Youtube](https://www.youtube.com/user/MiningGodBruce)) throughout summer & fall of 2016. As development went on, Ebin became more of a platform for experimental low-level graphics optimizations and coding practices. Work slowed down and eventually stopped when Bruce discovered a tragic fact: sometimes it's not possible to write code that is both "fast" and "clean". It was resumed by jbritain in 2024 because he liked the shaderpack and couldn't be bothered making his own.

This is a fork of Ebin which brings compatibility with modern versions of Minecraft, and also improves upon some aspects of the shader, using more modern features.

## Community
If you would like to discuss Ebin, or other Minecraft shaderpacks, join the [Shaderlabs Discord server](https://discord.gg/SMgEpZe).

## Features
- Sunlight Shadows / Shading
- Global Illumination
- Bloom / Glow
- Motion Blur
- Procedural 2D Clouds
- Procedural Water Waves
- Screen Space Reflections
- Terrain Parallax - 3D blocks with a supported texture pack
- Multi-Layered Shading Pipeline - Everything is correctly shaded*, even behind semi-transparent blocks
- Terrain Deformation - "Animal Crossing" and "Acid" deformations

*specular mapping support is currently experimental

## Planned Features
- Coloured Shadows
- Penumbra Shadows
- Improved Nether/End Support

## Requirements
- A relatively recent version of Iris or Optifine.
- OpenGL 4.1 compatible hardware

## Installation

1. Download and install a compatible version of Optifine or Iris
2. If you haven't already, launch the game once to create the 'shaderpacks' folder, which is located adjacent to your "saves" folder
3. Download the Ebin-Shaders .zip and place it into your 'shaderpacks' folder.

## If you run into problems
There is not a support team for using Ebin, and its primary developer does not have time to offer individual support to everybody who needs help. [Shaderlabs](https://discord.gg/SMgEpZe) is a popular Discord server for Minecraft shader development; you may be able to get help from somebody there.

## Team
- [jbritain](https://github.com/jbritain): Maintainer

## Contributors
- [BruceKnowsHow](https://github.com/BruceKnowsHow): Original Developer
- [dotModded](https://github.com/dotModded), [DethRaid](https://github.com/DethRaid), [zombye](https://github.com/zombye)


## Thanks
- [Sonic Ether](https://www.facebook.com/SonicEther/), creator of SEUS and inspiration for Ebin
- [daxnitro](http://www.minecraftforum.net/forums/mapping-and-modding/minecraft-mods/1272365), original creator of the Shaders Mod
- [karyonix](http://www.minecraftforum.net/forums/mapping-and-modding/minecraft-mods/1286604), longtime maintainer of the Shaders Mod
- [sp614x](https://twitter.com/sp614x), Ebin would not be possible without #include.
- [chocapic13](http://www.minecraftforum.net/forums/mapping-and-modding/minecraft-mods/1293898) & [Sildur](http://www.minecraftforum.net/forums/mapping-and-modding/minecraft-mods/1291396), various code references and help over the years
