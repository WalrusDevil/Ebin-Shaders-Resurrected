#include "/lib/Syntax.glsl"


varying vec2 texcoord;

#include "/lib/Uniform/Shading_Variables.glsl"

/***********************************************************************/
#if defined vsh
  void main() {
    texcoord    = gl_MultiTexCoord0.st;
    gl_Position = ftransform();
  }
#endif
/***********************************************************************/

/***********************************************************************/
#if defined fsh

layout (r32ui) uniform uimage2D waterdepth;

void main(){
  imageStore(waterdepth, ivec2(floor(gl_FragCoord.xy)), uvec4(floatBitsToUint(1.0), uvec3(0))); // clear water depth gtexture to 1.0 so atomic mins work correctly
}

#endif
/***********************************************************************/
