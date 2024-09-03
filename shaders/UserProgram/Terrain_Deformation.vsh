#if !defined DEFORMATION_GLSL
#define DEFORMATION_GLSL

vec3 UserDeformation(vec3 position) {
	position.y -= 20.0;
#if !defined gbuffers_shadow
	position.y += 1.6;
#endif
	position.xy = rotate(position.xy, position.x * 0.002 + radians(-52.0));
	position.y += 20.0;
#if !defined gbuffers_shadow
	position.y -= 1.6;
#endif
	return position;
}

vec3 Globe(vec3 position, cfloat radius) {
	position.y -= length2(position.xz) / radius;
	
	return position;
}

vec3 Acid(vec3 position) {
	position.zy = rotate(position.zy, sin(length2(position.xz) * 0.00005) * 0.8);
	
	return position;

	// position.xz = position.zx;
	// float worldTrome = cameraPosition.x * (20/8);
	// float distanceSquared = position.x * position.x + position.z * position.z;
	// position.x += sin(distanceSquared*sin(float(worldTrome)/(143.0 * 8))/1000);
	// //position.z += sin(distanceSquared*sin(float(worldTrome)/(143.0 * 8))/1000);
	// position.y += 8*sin(distanceSquared*sin(float(worldTrome)/(143.0 * 8))/2000);
			
	// float y = position.y;
	// float x = position.x;
	// float z = position.z;
			
	// float om = (sin(distanceSquared*sin(float(worldTrome)/131072.0)/5000) * sin(float(worldTrome)/400.0));
			
	// position.y = x*sin(om)+y*cos(om);
	// position.x = x*cos(om)-y*sin(om);
	// position.z = z;

	// position.xz = position.zx;

	// return position;
}

vec3 AnimalCrossing(vec3 position){
	position.y -= min(length2(position.xz) / 20, 20);
	return position;
}

vec3 TerrainDeformation(vec3 position) {
	
#ifdef DEFORM
	
	#if !defined gbuffers_shadow
		position += gbufferModelViewInverse[3].xyz;
	#endif
	
	#if DEFORMATION == 1
		
		position = Globe(position, 500.0);
		
	#elif DEFORMATION == 2
		
		position = Acid(position);
		
	#elif DEFORMATION == 3

		position = AnimalCrossing(position);

	#else
		
		position = UserDeformation(position);
		
	#endif
	
	#if !defined gbuffers_shadow
		position -= gbufferModelViewInverse[3].xyz;
	#endif
	
#endif
	
	return position;
}

#endif
