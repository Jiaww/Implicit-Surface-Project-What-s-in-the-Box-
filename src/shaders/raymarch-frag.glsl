#version 300 es

precision highp float;

#define PI 3.1415926
#define Epsilon 0.0001
#define GRADIENT_DELTA 0.0002
//#define SPIDER 

uniform float u_Time;
uniform vec2 u_Resolution;
uniform float u_SpiderTrig;
uniform float u_ShadowTrig;
uniform float u_AOTrig;
uniform float u_AnimationTrig;
uniform float u_RimTrig;
uniform float u_FogTrig;

out vec4 out_Col;

// rotation
vec2 r(vec2 v, float y){
    return cos(y)*v + sin(y)*vec2(-v.y, v.x);
}

//
vec3 smin(vec3 a, vec3 b){
    if (a.x < b.x)
        return a;

    return b;
}

vec3 smax(vec3 a, vec3 b){
    if (a.x > b.x)
        return a;
    
    return b;
}

vec3 signv(vec3 a){
    return vec3(-a.x, a.y, a.z);    
}

float sdSphere(vec3 p, float s){
  return length(p)-s;
}

// Round Box
float sdBox(vec3 p, vec3 b, float r){
  vec3 d = abs(p) - b;
  return min(max(d.x,max(d.y,d.z)),0.0) +
         length(max(d,0.0)) - r;
}

float sdCylinder( vec3 p, vec3 c ){
  return length(p.xz-c.xy)-c.z;
}

float sdCappedCylinder( vec3 p, vec2 h )
{
  vec2 d = abs(vec2(length(p.xz),p.y)) - h;
  return min(max(d.x,d.y),0.0) + length(max(d,0.0));
}

float sdConeSection( in vec3 p, in float h, in float r1, in float r2 )
{
    float d1 = -p.y - h;
    float q = p.y - h;
    float si = 0.5*(r1-r2)/h;
    float d2 = max( sqrt( dot(p.xz,p.xz)*(1.0-si*si)) + q*si - r2, q );
    return length(max(vec2(d1,d2),0.0)) + min(max(d1,d2), 0.);
}

float sdCapsule( vec3 p, vec3 a, vec3 b, float r )
{
    vec3 pa = p - a, ba = b - a;
    float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
    return length( pa - ba*h ) - r;
}

float sdEllipsoid( in vec3 p, in vec3 r )
{
    return (length( p/r ) - 1.0) * min(min(r.x,r.y),r.z);
}

//Plane - signed - exact
float sdPlane( vec3 p, vec4 n )
{
  // n must be normalized
  return dot(p,n.xyz) + n.w;
}

// // exponential smooth min/max (k = 32);
// float smoothmin( float a, float b, float k ){
//     return -log(exp(-k*a) + exp(-k*b))/k;
// }

// polynomial smooth min (k = 0.1);
float smoothmin( float a, float b, float k){
    float h = clamp( 0.5 + 0.5*(b-a)/k, 0.0, 1.0 );
    return mix( b, a, h ) - k*h*(1.0-h);
}

vec3 smoothmin( vec3 a, vec3 b, float k){
    float h = clamp( 0.5 + 0.5*(b.x-a.x)/k, 0.0, 1.0 );
    return mix( b, a, h ) - vec3(k*h*(1.0-h));
}

float smoothmax( float a, float b, float k ){
    return -log(exp(k*a) + exp(k*b))/-k;
}

//Union
float smoothopU( float d1, float d2, float k ){
    return smoothmin(d1,d2,k);
}

//Substraction d2 - d1
float opS( float d1, float d2 ){
    return max(-d1,d2);
}

float smoothopS( float d1, float d2, float k ){
    return smoothmax(-d1,d2,k);
}

//Intersection
float opI( float d1, float d2 ){
    return max(d1,d2);
}

float smoothopI( float d1, float d2, float k ){
    return smoothmax(d1,d2,k);
}

float cylsphere(vec3 p){
    float d = smoothopI(sdCylinder(p, vec3(0.0, 0.0, 0.04)), sdBox(p, vec3(0.3), 0.0), 48.0);
    d = smoothopU(d, sdSphere(p+vec3(0.0, 0.35, 0.0), 0.08), 0.1);
    d = smoothopU(d, sdSphere(p-vec3(0.0, 0.35, 0.0), 0.08), 0.1);
    return d;
}

vec3 snowman(vec3 p){
    //p.xz = r(p.xz, u_Time);
    p.xz = r(p.xz, PI * 0.15);
    float t = 1.0f - (sin(u_Time*2.0)+1.0)/2.0 * u_AnimationTrig;
    vec3 q;
    q = vec3(p.x, p.y-0.5, p.z-mix(0.01,0.0,t));
    float head = sdEllipsoid(q, vec3(0.5 * mix(0.95, 1.0, t), 0.5 * mix(1.1, 1.0, t), 0.5));
    float body = opS(sdBox(vec3(p.x, p.y+1.5, p.z), vec3(1.0,0.5,1.0), 0.01) ,sdEllipsoid(vec3(p.x, p.y+0.5, p.z), vec3(0.8 * mix(0.95, 1.0, t), 0.8 * mix(1.05, 1.0, t), 0.8)));
    // Nose
    q = p;
    q =vec3(q.x, q.y-0.5, q.z+0.5);
    q.yz = r(q.yz, PI * mix(0.35, 0.5, t));
    float nose = sdConeSection(q, 0.2, 0.1, 0.02);
    // Eyes
    float eyes = min(sdEllipsoid(vec3(p.x+0.2, p.y-0.6, p.z+0.4), vec3(0.08 * mix(0.9, 1.0, t), 0.08 * mix(1.4, 1.0, t), 0.08)), sdEllipsoid(vec3(p.x-0.2, p.y-0.6, p.z+0.4), vec3(0.08 * mix(0.9, 1.0, t), 0.08 * mix(1.4, 1.0, t), 0.08)));
    // Mouth
    float mouth = sdEllipsoid(vec3(p.x, p.y-0.3, p.z+0.4), vec3(0.05 * mix(1.25, 1.0, t), 0.05 * mix(1.75, 1.0, t), 0.1));
    head = opS(mouth, head);
    head = smoothopU(head, body, 0.1);
    // Hat
    q = vec3(p.x, p.y-1.0, p.z);
    q.z -= mix(0.3, 0.0, t);
    q.y -= mix(0.1, 0.0, t);
    q.yz = r(q.yz, -PI * mix(0.15, 0.0, t));
    float hat = sdCappedCylinder(q, vec2(0.4,0.1));
    q = vec3(p.x, p.y-0.85, p.z);
    q.z -= mix(0.2, 0.0, t);
    q.y -= mix(0.1, 0.0, t);
    q.yz = r(q.yz, -PI * mix(0.15, 0.0, t));
    hat = smoothopU(hat, sdCappedCylinder(q, vec2(0.52,0.02)), 0.1);
    // Arms
    q = vec3(p.x+0.7, p.y+0.025, p.z);
    q.xy = r(q.xy, PI * mix(0.95, 0.6, t));
    float leftarm = smoothopU(sdCappedCylinder(vec3(q.x, q.y, q.z), vec2(0.03,0.45)), sdSphere(vec3(q.x, q.y+0.45, q.z), 0.06), 0.1);
    q = vec3(p.x-0.7, p.y+0.025, p.z);
    q.xy = r(q.xy, -PI * mix(0.95, 0.6, t));
    float rightarm = smoothopU(sdCappedCylinder(vec3(q.x, q.y, q.z), vec2(0.03,0.45)), sdSphere(vec3(q.x, q.y+0.45, q.z), 0.06), 0.1);
    // Buttons
    float buttons = sdSphere(vec3(p.x, p.y, p.z+0.6), 0.08);
    buttons = min(buttons, sdSphere(vec3(p.x, p.y+0.25, p.z+0.725), 0.08));
    buttons = min(buttons, sdSphere(vec3(p.x, p.y+0.50, p.z+0.77), 0.08));
    vec3 final = vec3(head, 1.0, 0.0);
    final = smin(final, vec3(eyes, 0.0, 0.0));
    final = smin(final, vec3(nose, 5.0, 0.0));
    final = smin(final, vec3(hat, 0.0, 0.0));
    final = smin(final, vec3(leftarm, 2.0, 0.0));
    final = smin(final, vec3(rightarm, 2.0, 0.0));
    final = smin(final, vec3(buttons, 3.0, 0.0));
    return final;
}

vec3 spider(vec3 p){
    //p.xz = r(p.xz, u_Time);
    float scale = 0.3;
    //p.xz = r(p.xz, PI/2.0);
    float t = 1.0f - (sin(u_Time*2.0)+1.0)/2.0 * u_AnimationTrig;
    vec3 q = p;
    float head = sdEllipsoid(q, vec3(0.5, 0.3, 0.3) * scale);
    q.z -= 1.0 * scale;
    float body = sdEllipsoid(q, vec3(0.5, 0.4, 1.0) * scale);
    head = smoothopU(head, body, 0.1);
    // Eyes
    float eyes = min(sdEllipsoid(vec3(p.x+0.24 * scale, p.y-0.2 * scale, p.z+0.2 * scale), vec3(0.1) * scale), sdEllipsoid(vec3(p.x-0.24 * scale, p.y-0.2 * scale, p.z+0.2 * scale), vec3(0.1) * scale));
    // Legs
    q = vec3(p.x+0.7 * scale, p.y-0.2 * scale, p.z-0.5 * scale);
    q.xy = r(q.xy, PI * 0.6);
    float leftarm1 = smoothopU(sdCappedCylinder(vec3(q.x, q.y, q.z), vec2(0.05,0.45) * scale), sdSphere(vec3(q.x, q.y+0.45 * scale, q.z), 0.08 * scale), 0.1);
    q.y += 0.45 * scale;
    q.xy = r(q.xy, PI * 0.5);
    leftarm1 = smoothopU(leftarm1, sdCappedCylinder(vec3(q.x, q.y-0.45 * scale, q.z), vec2(0.05,0.45) * scale), 0.1);
    leftarm1 = smoothopU(leftarm1, sdSphere(vec3(q.x, q.y-0.9 * scale, q.z), 0.08 * scale), 0.1);
    
    q = vec3(p.x+0.7 * scale, p.y-0.2 * scale, p.z-1.0 * scale);
    q.xy = r(q.xy, PI * 0.6);
    float leftarm2 = smoothopU(sdCappedCylinder(vec3(q.x, q.y, q.z), vec2(0.05,0.45) * scale), sdSphere(vec3(q.x, q.y+0.45 * scale, q.z), 0.08 * scale), 0.1);
    q.y += 0.45 * scale;
    q.xy = r(q.xy, PI * 0.75 * scale);
    leftarm2 = smoothopU(leftarm2, sdCappedCylinder(vec3(q.x, q.y-0.45 * scale, q.z), vec2(0.05,0.45) * scale), 0.1);
    leftarm2 = smoothopU(leftarm2, sdSphere(vec3(q.x, q.y-0.9 * scale, q.z), 0.08 * scale), 0.1);

    q = vec3(p.x+0.7 * scale, p.y-0.2 * scale, p.z-1.5 * scale);
    q.xy = r(q.xy, PI * 0.45);
    float leftarm3 = smoothopU(sdCappedCylinder(vec3(q.x, q.y, q.z), vec2(0.05,0.45) * scale), sdSphere(vec3(q.x, q.y+0.45 * scale, q.z), 0.08 * scale), 0.1);
    q.y += 0.45 * scale;
    q.xy = r(q.xy, PI * 0.5);
    leftarm3 = smoothopU(leftarm3, sdCappedCylinder(vec3(q.x, q.y-0.45 * scale, q.z), vec2(0.05,0.45) * scale), 0.1);
    leftarm3 = smoothopU(leftarm3, sdSphere(vec3(q.x, q.y-0.9 * scale, q.z), 0.08 * scale), 0.1);

    q = vec3(p.x-0.7 * scale, p.y-0.2 * scale, p.z-0.5 * scale);
    q.xy = r(q.xy, -PI * 0.6);
    float rightarm1 = smoothopU(sdCappedCylinder(vec3(q.x, q.y, q.z), vec2(0.05,0.45) * scale), sdSphere(vec3(q.x, q.y+0.45 * scale, q.z), 0.08 * scale), 0.1);
    q.y += 0.45 * scale;
    q.xy = r(q.xy, -PI * 0.5);
    rightarm1 = smoothopU(rightarm1, sdCappedCylinder(vec3(q.x, q.y-0.45 * scale, q.z), vec2(0.05,0.45) * scale), 0.1);
    rightarm1 = smoothopU(rightarm1, sdSphere(vec3(q.x, q.y-0.9 * scale, q.z), 0.08 * scale), 0.1);
    
    q = vec3(p.x-0.7 * scale, p.y-0.2 * scale, p.z-1.0 * scale);
    q.xy = r(q.xy, -PI * 0.4);
    float rightarm2 = smoothopU(sdCappedCylinder(vec3(q.x, q.y, q.z), vec2(0.05,0.45) * scale), sdSphere(vec3(q.x, q.y+0.45 * scale, q.z), 0.08 * scale), 0.1);
    q.y += 0.45 * scale;
    q.xy = r(q.xy, -PI * 0.5);
    rightarm2 = smoothopU(rightarm2, sdCappedCylinder(vec3(q.x, q.y-0.45 * scale, q.z), vec2(0.05,0.45) * scale), 0.1);
    rightarm2 = smoothopU(rightarm2, sdSphere(vec3(q.x, q.y-0.9 * scale, q.z), 0.08 * scale), 0.1);

    q = vec3(p.x-0.7 * scale, p.y-0.2 * scale, p.z-1.5 * scale);
    q.xy = r(q.xy, -PI * 0.65);
    float rightarm3 = smoothopU(sdCappedCylinder(vec3(q.x, q.y, q.z), vec2(0.05,0.45) * scale), sdSphere(vec3(q.x, q.y+0.45 * scale, q.z), 0.08 * scale), 0.1);
    q.y += 0.45 * scale;
    q.xy = r(q.xy, -PI * 0.5);
    rightarm3 = smoothopU(rightarm3, sdCappedCylinder(vec3(q.x, q.y-0.45 * scale, q.z), vec2(0.05,0.45) * scale), 0.1);
    rightarm3 = smoothopU(rightarm3, sdSphere(vec3(q.x, q.y-0.9 * scale, q.z), 0.08 * scale), 0.1);

    vec3 final = vec3(head, 4.0, 0.0);
    final = smin(final, vec3(eyes, 0.0, 0.0));
    final = smin(final, vec3(leftarm1, 0.0, 0.0));
    final = smin(final, vec3(leftarm2, 0.0, 0.0));
    final = smin(final, vec3(leftarm3, 0.0, 0.0));
    final = smin(final, vec3(rightarm1, 0.0, 0.0));
    final = smin(final, vec3(rightarm2, 0.0, 0.0));
    final = smin(final, vec3(rightarm3, 0.0, 0.0));
    return final;
}

vec3 giftbox(vec3 p){
    float scale = 0.3;
    float t = 1.0f - (sin(u_Time*2.0)+1.0)/2.0 * u_AnimationTrig;
    vec3 q = p;
    float box = sdBox(q, vec3(0.5, 0.36, 0.5), 0.025);
    q.y -= 0.1;
    box = opS(sdBox(q, vec3(0.45, 0.36, 0.45), 0.025), box);
    q.y -= 0.36;
    q.x += mix(0.52, 0.0, t);
    q.y -= mix(0.45, 0.0, t);
    q.xy = r(q.xy, -mix(PI*0.4, 0.0, t));
    float lib = sdBox(q, vec3(0.52, 0.10, 0.52), 0.025);
    vec3 final = vec3(min(box, lib), 6.0, 0.0);
    return final;
}

vec3 map( vec3 p ){   
    // p.xz = r(p.xz, u_Time);
    float t = 1.0f - (sin(u_Time*2.0)+1.0)/2.0 * u_AnimationTrig;
    vec3 q = p;
    vec3 snowmanVec = snowman(q);
    q = vec3(q.x + 2.5, q.y+0.65, q.z+1.5);
    vec3 boxVec = giftbox(q);
    q = p;
    q.y += 1.0;
    vec3 planeVec = vec3(sdBox(q, vec3(5.0, 0.1, 5.0), 0.0), 9.0, 0.0);

    if(u_SpiderTrig == 1.0){
        q = p;
        q = vec3(q.x + 2.3, q.y+0.65, q.z+1.5);
        q.y -= mix(0.5, 0.0, t);
        q.xz = r(q.xz, -PI * 0.55);
        vec3 spiderVec = spider(q);
        return smin(smin(boxVec, spiderVec), smin(snowmanVec, planeVec));
    }
    else
        return smin(boxVec, smin(snowmanVec, planeVec));
}

vec3 colorize(float index){
    // Black
    if (index == 0.0)
        return vec3(0.1, 0.1, 0.1);
    // Light yellow
    if (index == 1.0)
        return vec3(1.0,1.0,0.9);
    // Brown
    if (index == 2.0)
        return vec3(0.54, 0.27, 0.075);
    // Green
    if (index == 3.0)
        return vec3(0.5, 0.8, 0.6);
    // Dark yellow
    if (index == 4.0)
        return vec3(0.3, 0.3, 0);
    // Red
    if (index == 5.0)
        return vec3(1.0, 0.2, 0.3);
    // Pink
    if (index == 6.0)
        return vec3(1.0, 0.78, 0.8);
    // White
    if (index == 9.0)
        return vec3(0.95, 0.95, 0.95);
    
    return vec3(index / 10.0);
}

float ao(vec3 v, vec3 n) {
    const int ao_iterations = 10;
    const float ao_step = 0.15;
    const float ao_scale = 0.75;
    
    float sum = 0.0;
    float att = 1.0;
    float len = ao_step;
    
    for (int i = 0; i < ao_iterations; i++)
    {
        sum += (len - map(v + n * len).x) * att;        
        len += ao_step;     
        att *= 0.5;
    }
    
    return 1.0 - max(sum * ao_scale, 0.0);
}


float softshadow( in vec3 ro, in vec3 rd, float mint, float maxt, float k ){
    float res = 1.0;
    for( float t=mint; t < maxt; )
    {
        float h = map(ro + rd*t).x;
        if( h<0.001 )
            return 0.25;
        res = min( res, k*h/t );
        t += h;
    }
    return res;
}

void main() {
    // TODO: make a Raymarcher!

    vec3 q = vec3((gl_FragCoord.xy / u_Resolution.xy - 0.5), 1.0);
    //float vignette = 1.0 - length(q.xy);
    q.x *= u_Resolution.x / u_Resolution.y;
    q.y -= 0.25;
    vec3 p = vec3(0.0, 0.0, -5.0);
    out_Col = vec4(1.0, 0.5, 0.0, 1.0);
    q = normalize(q);
    //q.xz = r(q.xz, u_Time * 0.1);
    p.y += 1.25;
    p.x -= 1.3;
    p.z -= 0.5;

    float t = 0.0;
    // d.x: distance; d.y: colorize
    vec3 d = vec3(0.0);
    const float maxSteps = 96.0;
    // Ray Marching
    for (float tt = 0.0; tt < maxSteps; ++tt){
        d = map(p + q*t);
        t += d.x*0.45;
        if(!(t<=50.0) || d.x <= Epsilon)
            break;
    }

    vec3 fog = vec3(0.7, 0.75, 0.8);
    vec3 color = fog;

    vec3 ldir = normalize(vec3(1.0, 0.75, -1.0));
    vec3 hit = vec3(0.0);
    vec3 normal = vec3(0.0);
    float shadow = 1.0;
    float fao = 1.0;
    // inside view distance
    if (t <= 50.0){
        hit = p + q*t;
        vec2 delta = vec2(0.001, 0.00);
        // compute normal using dxdy
        normal= vec3( map(hit + delta.xyy).x - map(hit - delta.xyy).x, map(hit + delta.yxy).x - map(hit - delta.yxy).x, map(hit + delta.yyx).x - map(hit - delta.yyx).x);
        normal = normalize(normal);

        // Shadow
        if (u_ShadowTrig == 1.0)
           shadow = softshadow(hit + normal * 0.01, ldir, 0.01, 25.0, 32.0);
        // Ambient Occlusion
        if (u_AOTrig == 1.0)
            fao = ao(hit, normal);

        vec3 light = (0.5 * color.rgb + vec3(0.5 * fao * abs(dot(normal, ldir)))) * colorize(d.y);
        // rim
        if (u_RimTrig == 1.0)
          light += (1.0 - t / 50.0) * vec3(fao * pow(1.0 - abs(dot(normal, q)), 4.0)); 
        vec3 reflectDir = reflect(q, normal);
        light += fao * vec3(pow(abs(dot(q, ldir)), 64.0));
        color = min(vec3(1.0), light);
        color *= fao;
    }
    color = shadow * color;
    // fog
    if (u_FogTrig == 1.0)
       color = mix(color, fog, pow(min(1.0, t / 50.0), 0.7));
    // contrast
    color = smoothstep(0.0, 1.0, color); 
    out_Col = vec4(color, 1.0);
}