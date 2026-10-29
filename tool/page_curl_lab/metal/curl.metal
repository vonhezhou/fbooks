#include <metal_stdlib>
using namespace metal;
struct Uniforms { float4 shape; float4 options; };
struct Projected { float3 point; float light; };
struct Varying { float4 position [[position]]; float2 uv; float light; float pass [[flat]]; float height; };
struct Contact { float4 position [[position]]; float distance; float width; float alpha; };
constant float pi = 3.141592653589793;
float4 rowGeometry(float y, constant Uniforms& u) {
  float w=u.shape.x,h=u.shape.y,t=clamp(u.shape.z,0.0000001f,0.9999999f);
  float wave=sin(pi*t),row=y/h,grab=clamp(u.shape.w,0.0f,1.0f);
  float radius=w*0.105f*pow(wave,0.6f)*(0.82f+0.3f*abs(row-grab));
  float crease=w*(1-t)-pi*radius*0.5f+(grab-0.5f)*0.9f*(grab-row)*w*wave;
  float d=-crease,a=clamp(d/radius,0.0f,pi);
  float along=d<=0?d:d<pi*radius?radius*sin(a):-(d-pi*radius);
  return float4(radius,crease,along,d<=0?0:radius*(1-cos(a)));
}
Projected projectPaper(float2 uv, constant Uniforms& u) {
  float w=u.shape.x,h=u.shape.y,t=u.shape.z;
  if(t<=0||t>=1)return {float3((t<=0?1.0f:-1.0f)*uv.x*w,uv.y*h,0),1};
  float4 g=rowGeometry(uv.y*h,u);float d=uv.x*w-g.y,a=clamp(d/g.x,0.0f,pi);
  float s=sin(a),c=cos(a),along=d<=0?d:d<pi*g.x?g.x*s:-(d-pi*g.x);
  float z=(d<=0?0:g.x*(1-c))-g.w;
  float weight=1-abs(uv.y-u.shape.w),perspective=1/(1-z/(w*5));
  float pull=(u.shape.w-0.5f)*0.9f*h*0.07f*sin(pi*t)*uv.x*uv.x*weight*weight;
  float light=clamp(0.74f+0.26f*abs(c)+0.12f*pow(s,12.0f),0.0f,1.0f);
  return {float3((along-g.z)*perspective,(uv.y*h-pull-h*0.5f)*perspective+h*0.5f,z),light};
}
float4 clipPosition(float2 p,float depth,constant Uniforms& u) {
  float total=u.shape.x*(u.options.x>0.5f?2:1);
  if(u.options.y>0.5f)p.x=total-p.x;
  return float4(2*p.x/total-1,1-2*p.y/u.shape.y,depth,1);
}
vertex Varying curlVertex(uint id [[vertex_id]], const device float2* vertices [[buffer(0)]],constant Uniforms& u [[buffer(1)]]) {
  float2 uv=vertices[id];float w=u.shape.x;float pass=u.options.z;
  float origin=u.options.x>0.5f?w:0;Projected p=projectPaper(uv,u);
  float2 position;float depth;
  if(pass==1){position=float2(uv.x*w,uv.y*u.shape.y);depth=0.9f;}
  else if(pass==2){position=float2(origin+uv.x*w,uv.y*u.shape.y);depth=0.9f;}
  else if(pass==4){position=float2(uv.x*w*(u.options.x>0.5f?2:1),uv.y*u.shape.y);depth=0.8f;}
  else if(pass==5){position=float2(origin+(uv.x-0.5f)*w*0.05f,uv.y*u.shape.y);depth=0;}
  else {position=p.point.xy+float2(origin,0);depth=0.5f-p.point.z/(w*8);
    if(pass==3){position+=p.point.z*float2(0.22f,0.10f);depth=0.5f;}}
  return {clipPosition(position,depth,u),uv,p.light,pass,p.point.z};
}
fragment float4 curlFragment(Varying v [[stage_in]],bool front [[front_facing]],constant Uniforms& u [[buffer(0)]],texture2d<float> page [[texture(0)]],texture2d<float> back [[texture(1)]],sampler linearSampler [[sampler(0)]]) {
  if(v.pass==3)return float4(0,0,0,0.18f*smoothstep(0.0f,3.0f,v.height));
  if(v.pass==5)return float4(0,0,0,0.16f*(1-abs(v.uv.x*2-1)));
  float2 uv=v.uv;
  if(v.pass==4)return page.sample(linearSampler,uv);
  bool reverse=v.pass==0&&!front;
  if(reverse&&u.options.x>0.5f)uv.x=1-uv.x;
  if(u.options.y>0.5f)uv.x=1-uv.x;
  float4 color=reverse&&u.options.x>0.5f?back.sample(linearSampler,uv):page.sample(linearSampler,uv);
  if(v.pass>0)return color;
  float light=floor(v.light*255+0.5f)/255;color.rgb*=light;
  if(reverse&&u.options.x<0.5f){float alpha=224.0f/255.0f;float3 paper=round(float3(250,246,236)*light)/255;color=float4(paper*alpha+color.rgb*(1-alpha),alpha+color.a*(1-alpha));}
  return color;
}
vertex Contact contactVertex(uint id [[vertex_id]],const device float2* vertices [[buffer(0)]],constant Uniforms& u [[buffer(1)]]) {
  float2 uv=vertices[id];float4 g=rowGeometry(uv.y*u.shape.y,u);float w=u.shape.x;
  float d=w*5,h=d-g.x+g.w;
  float edge=d*(-g.z*h+g.x*sqrt(max(0.0f,h*h+g.z*g.z-g.x*g.x)))/(h*h-g.x*g.x);
  float material=clamp((g.y+g.x*(pi*0.5f+atan(edge/d)))/w,0.0f,1.0f);
  Projected p=projectPaper(float2(material,uv.y),u),end=projectPaper(float2(1,uv.y),u);
  float lift=max(0.0f,end.point.z),width=0.8f+lift*0.025f;
  float distance=(uv.x*2-1)*width*4;
  float2 xy=p.point.xy+float2(distance+(u.options.x>0.5f?w:0),0);
  return {clipPosition(xy,0.75f,u),distance,width,0.10f*smoothstep(0.0f,3.0f,lift)};
}
fragment float4 contactFragment(Contact v [[stage_in]]) {
  return float4(0,0,0,v.alpha*exp(-abs(v.distance)/v.width));
}
