shader_type spatial;
render_mode cull_disabled;
uniform vec4 base_color: source_color = vec4(0.42,0.68,0.76,1.0);
uniform int example_kind = 0;
uniform int feature_code = 0;
uniform bool show_color = true;
varying vec3 wp;
varying vec3 wn;
void vertex(){
 wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 wn=normalize((MODEL_MATRIX*vec4(NORMAL,0.0)).xyz);
}
void fragment(){
 ALBEDO=base_color.rgb;
 ROUGHNESS=0.78;
 bool marked=false;
 float x=wp.x*1000.0;
 float y=-wp.z*1000.0;
 float z=wp.y*1000.0;
 if(feature_code==1){marked=true;}
 if(example_kind==1){
  if(feature_code==2){marked=abs(wn.y-0.7071)<0.08 && abs(wn.x+0.7071)<0.08;}
  if(feature_code==3){marked=(abs(z-42.0)<0.2 && wn.y>0.8) || (abs(abs(y)-7.0)<0.2 && z>41.9);}
 }
 if(example_kind==2){
  if(feature_code==4){marked=abs(length(vec2(x,z-36.0))-12.0)<0.25;}
  if(feature_code==3){marked=(abs(abs(x)-17.0)<0.2 && y>11.9) || (abs(y-12.0)<0.2 && abs(x)<17.1);}
  if(feature_code==5){marked=y<-4.9 && z>35.9 && abs(length(vec2(x,z-36.0))-20.0)<0.3;}
 }
 if(example_kind==3){
  if(feature_code==6){marked=abs(length(vec2(x,z-38.0))-12.0)<0.25;}
  if(feature_code==7){marked=abs(length(vec2(y+20.0,z-12.0))-7.0)<0.25;}
  if(feature_code==5){marked=abs(length(vec2(x,z-38.0))-26.0)<0.3 || abs(length(vec2(y+20.0,z-12.0))-12.0)<0.3;}
 }
 if(marked && show_color){ALBEDO=mix(ALBEDO,vec3(1.0,0.69,0.35),0.48);}
}
