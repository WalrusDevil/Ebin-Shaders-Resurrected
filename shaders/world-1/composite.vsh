#include "/lib/GLSL_Version.glsl"
#define composite0
#define vsh
#define world2
#define ShaderStage 10

#ifdef COMPOSITE0_ENABLED
#include "/composite0.glsl"
#else
#include "/gbuffers_discard.glsl"
#endif
