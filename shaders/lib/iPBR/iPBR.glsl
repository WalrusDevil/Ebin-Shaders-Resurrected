#ifndef IPBR
#define IPBR

#include "/lib/iPBR/IDs.glsl"
#include "/lib/iPBR/Groups.glsl"

struct PBRData {
  vec4 albedo;
  vec3 hsv;
  float perceptualSmoothness;
  float baseReflectance;
  float porosity;
  float SSS;
  float emission;

  float materialAO;
  float height;
  vec3 normal;
};

void applyiPBR(inout float val, float newVal){
  if(val == 0.0){
    val = newVal;
  }
}

float generateEmission(PBRData data, float lumaThreshold, float satThreshold){

  float luma = data.hsv.b;
	float sat = data.hsv.g;

  if(luma < lumaThreshold){
    return smoothstep(satThreshold, 1.0, sat);
  }

  return luma;
}

#ifdef gbuffers_main
  PBRData getRawPBRData(vec2 coord){
    vec4 specularData = texture(specular, coord);
    vec4 normalData = texture(normals, coord);

    PBRData data;

    data.albedo = GetDiffuse(coord);
    data.hsv = hsv(data.albedo.rgb);

    data.perceptualSmoothness = specularData.r;
    data.baseReflectance = specularData.g;

    float porositySSS = specularData.b;
    data.porosity = porositySSS <= 0.25 ? porositySSS * 4.0 : 0.0;
    data.SSS = porositySSS > 0.25 ? (porositySSS - 0.25) * (4.0/3.0) : 0.0;

    if (data.porosity > 0){
			data.baseReflectance = mix(data.baseReflectance, 0.1 * data.porosity, wetness * vertLightmap.g);
			data.perceptualSmoothness = mix(data.perceptualSmoothness, (1.0 - data.porosity), wetness * vertLightmap.g);
		}

    data.emission = specularData.a != 1.0 ? specularData.a : 0.0;

    data.materialAO = normalData.b;
    data.height = normalData.a * 0.75 + 0.25;
    data.normal.xy = normalData.xy * 2.0 - 1.0;
    data.normal.z = sqrt(1.0 - dot(data.normal.xy, data.normal.xy));
    data.normal = normalize(data.normal);

    return data;
  }

  void injectIPBR(inout PBRData data, float ID){
    switch(int(ID + 0.5)){
      case IPBR_WATER:
        data.perceptualSmoothness = 1.0;
        data.baseReflectance = 0.02;
        break;

      case IPBR_ICE:
        applyiPBR(data.perceptualSmoothness, 1.0);
        applyiPBR(data.baseReflectance, 0.02);
        break;

      case IPBR_NETHER_PORTAL:
        applyiPBR(data.perceptualSmoothness, 1.0);
        applyiPBR(data.baseReflectance, 0.02);
        applyiPBR(data.emission, 0.7);
        break;

      case IPBR_IRON:
        applyiPBR(data.baseReflectance, 230.0/255.0);
        applyiPBR(data.perceptualSmoothness, 0.8);
        break;

      case IPBR_GOLD:
        applyiPBR(data.baseReflectance, 231.0/255.0);
        applyiPBR(data.perceptualSmoothness, 0.8);
        break;

      case IPBR_GLASS:
        applyiPBR(data.baseReflectance, 0.02);
        applyiPBR(data.perceptualSmoothness, 0.8);

    }

    if(IPBR_EMITS_LIGHT(ID))   applyiPBR(data.emission, generateEmission(data, 0.8, 0.6));

    if(IPBR_IS_FOLIAGE(ID)){
      applyiPBR(data.SSS, 1.0);
      applyiPBR(data.baseReflectance, 0.03);
      applyiPBR(data.perceptualSmoothness, 0.5 * smoothstep(0.16, 0.5, data.hsv.b));
    }   

  }
#endif

#endif