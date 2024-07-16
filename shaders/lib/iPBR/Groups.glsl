#ifndef IPBR_GROUPS
#define IPBR_GROUPS

bool IPBR_EMITS_LIGHT(int ID){
	return 
    (ID >= 1000 && ID < 2000);
}

bool IPBR_IS_FOLIAGE(int ID){
  return
    (ID >= 2000 && ID < 3000);
}
#endif