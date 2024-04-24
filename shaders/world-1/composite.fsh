#include "/lib/GLSL_Version.glsl"
#define composite0
#define fsh
#define world2
#define ShaderStage 0

#ifdef COMPOSITE0_ENABLED
#include "/composite0.glsl"
#else
#include "/gbuffers_discard.glsl"
#endif
