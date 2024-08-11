#include "/lib/Syntax.glsl"
#include "/lib/Settings.glsl"


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

#ifdef PREPARE_ENABLED
layout (r32ui) uniform uimage2D waterdepth;
#endif

void main(){
  #ifdef PREPARE_ENABLED
  imageStore(waterdepth, ivec2(floor(gl_FragCoord.xy)), uvec4(floatBitsToUint(1.0), uvec3(0))); // clear water depth gtexture to 1.0 so atomic mins work correctly
  #endif
}

#endif
/***********************************************************************/
