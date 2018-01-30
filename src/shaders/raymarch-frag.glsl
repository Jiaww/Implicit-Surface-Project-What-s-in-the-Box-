#version 300 es

precision highp float;

#define PI 3.1415926
#define Epsilon 0.0001
#define GRADIENT_DELTA 0.0002

uniform float u_Time;
uniform vec2 u_Resolution;

out vec4 out_Col;

float hash(float n){
	return fract(sin(n)*43758.5453123);
}

float noise2(in vec2 x){
	vec2 p = floor(x);
	vec2 f = fract(x);
	f = f * f * (3.0 - 2.0*f);

	float n = p.x + p.y*157.0;
    return mix(mix(hash(n+0.0), hash(n+1.0),f.x), mix(hash(n+157.0), hash(n+158.0),f.x),f.y);
}

float noise3(in vec3 x){
    vec3 p = floor(x);
    vec3 f = fract(x);
    f = f*f*(3.0-2.0*f);
	
    float n = p.x + p.y*157.0 + 113.0*p.z;
    return mix(
        mix(mix(hash(n+  0.0), hash(n+  1.0),f.x), mix(hash(n+157.0), hash(n+158.0),f.x),f.y),
        mix(mix(hash(n+113.0), hash(n+114.0),f.x), mix(hash(n+270.0), hash(n+271.0),f.x),f.y),f.z);
}

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


// exponential smooth min/max (k = 32);
float smoothmin( float a, float b, float k ){
    return -log(exp(-k*a) + exp(-k*b))/k;
}

float smoothmax( float a, float b, float k ){
    return -log(exp(k*a) + exp(k*b))/-k;
}

//Union
float smoothopU( float d1, float d2, float k ){
    return smoothmin(d1,d2,k);
}

//Substraction d2 - d1
float smoothopS( float d1, float d2, float k ){
    return smoothmax(-d1,d2,k);
}

//Intersection
float smoothopI( float d1, float d2, float k ){
    return smoothmax(d1,d2,k);
}

float cylsphere(vec3 p){
    float d = smoothopI(sdCylinder(p, vec3(0.0, 0.0, 0.04)), sdBox(p, vec3(0.3), 0.0), 48.0);
    d = smoothopU(d, sdSphere(p+vec3(0.0, 0.35, 0.0), 0.08), 48.0);
    d = smoothopU(d, sdSphere(p-vec3(0.0, 0.35, 0.0), 0.08), 48.0);
    return d;
}

vec3 greeble0(vec3 p, float phase){
	// determine the state of current greeble
	float t = mod(phase + u_Time * 0.5, 1.0);
	float rotation = sign(phase-0.5) * min(1.0, max(0.0, -0.2 + 5.0*t)) * PI/2.0;
	float translation = min(1.0, max(0.0, 2.0 * sin(min(t - 0.02, 0.5) * 10.0)));

	float d = sdBox(p, vec3(0.4), 0.075);
	float e = sdSphere(p - vec3(0.0, 0.6, 0.0), 0.2);
	d = smoothopS(e, d, 32.0);
	// Question??? 1
	p.y -= translation * 0.3 - 0.1;
	p.xz = r(p.xz, rotation);
	e = smoothopI(sdCylinder(p, vec3(0.0, 0.0, 0.1)), sdBox(p, vec3(0.8), 0.0), 48.0);
	vec3 q = p;
	q.y -= 0.8;
	q.yz = r(q.yz, PI/2.0);
	e = smoothopU(e, cylsphere(q), 16.0);
	q.xy = r(q.xy,PI/2.0);
    e = smoothopU(e, cylsphere(q), 16.0);
    return smin(vec3(d, 0.0, 0.0), vec3(e, 1.0, 0.0));
}

vec3 greeble1(vec3 p, float phase){
	float t = mod(phase + sign(phase - 0.5) * u_Time * 0.5, 1.0);

	float d = sdBox(p, vec3(0.425), 0.05);
	d = smoothopS(sdBox(p + vec3(0.0, 0.0, 0.3), vec3(0.3, 1.0, 0.01), 0.0), d, 32.0);
    d = smoothopS(sdBox(p - vec3(0.0, 0.0, 0.3), vec3(0.3, 1.0, 0.01), 0.0), d, 32.0);
    d = smoothopS(sdBox(p + vec3(0.3, 0.0, 0.0), vec3(0.01, 1.0, 0.3), 0.0), d, 32.0);
    d = smoothopS(sdBox(p - vec3(0.3, 0.0, 0.0), vec3(0.01, 1.0, 0.3), 0.0), d, 32.0);

    float x = max(-1.0, min(1.0, 4.0*cos(t*2.0*PI)));
    float z = max(-1.0, min(1.0, 4.0*sin(t*2.0*PI)));
    x *= 0.3;
    z *= 0.3;
    vec3 q = p + vec3(x, 0.0, z);
    float e = sdBox(q, vec3(0.03, 0.75, 0.03), 0.0);
    q.y -= 0.75;
    e = smoothopU(e, sdSphere(q, 0.1), 32.0);
    return smin(vec3(d, 2.0, 0.0), vec3(e, 3.0, 0.0));
}

vec3 greeble2(vec3 p, float phase)
{
    float d = sdBox(p, vec3(0.425), 0.05);
    d = smoothopS(sdBox(p + vec3(0.2, 0.0, 0.0), vec3(0.01, 1.0, 0.3), 0.0), d, 32.0);
    d = smoothopS(sdBox(p - vec3(0.2, 0.0, 0.0), vec3(0.01, 1.0, 0.3), 0.0), d, 32.0);
    
    float x = pow(mod(phase + sign(phase-0.5) * u_Time * 0.5, 1.0), 2.0) * 2.0 * PI;
    float t = max(-0.5, min(0.5, sin(x)));
    p.yz = r(p.yz, t);
    vec3 q = p + vec3(0.0, 0.25, 0.0);
    float e =  sdBox(q - vec3(0.2, 0.0, 0.0), vec3(0.02, 1.0, 0.02), 0.0);
    e = min(e, sdBox(q + vec3(0.2, 0.0, 0.0), vec3(0.02, 1.0, 0.02), 0.0));
    e = min(e, sdBox(q - vec3(0.0, 1.0, 0.0), vec3(0.175, 0.02, 0.02), 0.0));
    e = smoothopU(e, sdSphere(q - vec3(0.2, 1.01, 0.0), 0.03), 32.0);
    e = smoothopU(e, sdSphere(q - vec3(-0.2, 1.01, 0.0), 0.03), 32.0);
    q.y -= 1.0;
    q.xy = r(q.xy, PI / 2.0);
    e = smoothopU(e, max(sdCylinder(q, vec3(0.0, 0.0, 0.03)), sdBox(q, vec3(0.1), 0.0)), 32.0);
    return smin(vec3(d, 4.0, 0.0), vec3(e, 5.0, 0.0));
}

vec3 greeble3(vec3 p, float phase)
{
    float d = sdBox(p, vec3(0.4), 0.08);
    ivec2 i = ivec2(p.xz / 0.15 + floor(phase * 815.0));
    float phase2 = noise2(vec2(i));
    vec3 q = p;
    q.xz = mod(q.xz, 0.15);
    q.xz -= 0.075;
    q.y -= 0.5;
    float hole = smoothopI(sdBox(q, vec3(0.05, 1.0, 0.05), 0.0), sdBox(p, vec3(0.3, 2.0, 0.3), 0.0), 32.0);
    d = smoothopS(hole, d, 96.0);
    
    float t = phase2 * 2.0 * PI + u_Time * 8.0;
    q.y -= 0.1 * max(-0.5, min(0.5, sin(t)));
    q.y += 0.5;
    float e = sdBox(q, vec3(0.025, 0.6, 0.025), 0.0);
    e = smoothopI(e, sdBox(p, vec3(0.3, 2.0, 0.3), 0.0), 32.0);
    return smin(vec3(d, 6.0, 0.0), vec3(e, 7.0, 0.0));
}

vec3 greeble4(vec3 p, float phase)
{
    float angle = floor(phase * 4.0) * 0.5 * PI;
    p.xz = r(p.xz, angle);
    float d = sdBox(p, vec3(0.4), 0.08);
    d = smoothopS(sdBox(p - vec3(0.2, 0.0, 0.1), vec3(0.1, 1.0, 0.2), 0.0), d, 32.0);
    d = smoothopS(sdBox(p + vec3(0.2, 0.0, -0.1), vec3(0.1, 1.0, 0.2), 0.0), d, 32.0);
    vec3 q = p - vec3(0.0, 0.8, -0.3);
    float e = sdBox(q + vec3(0.0, 0.2, 0.0), vec3(0.0, 0.15, 0.0), 0.1) / 0.6;
    q /= 0.6;
    q.yz = r(q.yz,PI/2.0);
    
    float t = phase + 0.2 * u_Time;
    angle = 0.45 * max(-1.0, min(1.0, 4.0*cos(t*2.0*PI)));
    float y = 0.5 + 0.5 * max(-1.0, min(1.0, 4.0*sin(t*2.0*PI)));
    y = pow(y, 1.25 + 0.75 * cos(t*2.0*PI));
    q.xy = r(q.xy, angle);
    q.y += 0.4;
    
    e = smoothopU(e, cylsphere(q), 16.0);
    q += vec3(0.0, 0.35, 0.05);
    e = min(e, sdBox(q, vec3(0.0, 0.0, -0.1), 0.2)) * 0.6;
    float f = sdBox(q + vec3(0.0, 0.0, 1.2 - y), vec3(0.1), 0.0) * 0.6;
    return smin(smin(vec3(d, 8.0, 0.0), vec3(e, 9.0, 0.0)), vec3(f, 10.0, 0.0));
}

vec3 greeble(vec3 p, float findex, float phase)
{
    const int indexCount = 6;
    int index = int(findex * float(indexCount));
    p.y -= phase * 0.2 - 0.2;
    if (index == 0)
        return greeble0(p, phase);
    else if (index == 1)
        return greeble1(p, phase);
    else if (index == 2)
        return greeble2(p, phase);
    else if (index == 3)
        return greeble3(p, phase);
    else if (index == 4)
        return greeble4(p, phase);
        
    return vec3(sdBox(p, vec3(0.4), 0.025), 10.0, 0.0);
}

vec3 f( vec3 p )
{
    ivec3 h = ivec3(p+1337.0);
    float hash = noise2(vec2(h.xz));
    h = ivec3(p+42.0);
    float phase = noise2(vec2(h.xz));
    vec3 q = p;
    q.xz = mod(q.xz, 1.0);
    q -= 0.5;
	return greeble(q, hash, phase);
}

vec3 colorize(float index)
{
    if (index == 0.0)
        return vec3(0.4, 0.6, 0.2);
    
    if (index == 1.0)
        return vec3(0.6, 0.3, 0.2);
    
    if (index == 2.0)
        return vec3(1.0, 0.8, 0.5);
    
    if (index == 3.0)
        return vec3(0.9, 0.2, 0.6);
    
    if (index == 4.0)
        return vec3(0.3, 0.6, 0.7);
    
    if (index == 5.0)
        return vec3(1.0, 1.0, 0.3);
    
    if (index == 6.0)
        return vec3(0.7, 0.5, 0.7);
    
    if (index == 7.0)
        return vec3(0.4, 0.3, 0.4);
    
    if (index == 8.0)
        return vec3(0.8, 0.3, 0.2);
    
    if (index == 9.0)
        return vec3(0.5, 0.8, 0.2);
    
	return vec3(index / 10.0);
}

float ao(vec3 v, vec3 n) 
{
    const int ao_iterations = 10;
    const float ao_step = 0.2;
    const float ao_scale = 0.75;
    
	float sum = 0.0;
	float att = 1.0;
	float len = ao_step;
    
	for (int i = 0; i < ao_iterations; i++)
    {
		sum += (len - f(v + n * len).x) * att;		
		len += ao_step;		
		att *= 0.5;
	}
	
	return 1.0 - max(sum * ao_scale, 0.0);
}


float softshadow( in vec3 ro, in vec3 rd, float mint, float maxt, float k )
{
    float res = 1.0;
    for( float t=mint; t < maxt; )
    {
        float h = f(ro + rd*t).x;
        if( h<0.001 )
            return 0.1;
        res = min( res, k*h/t );
        t += h;
    }
    return res;
}

vec3 gradientNormal(vec3 p) {
    return normalize(vec3(
        f(p + vec3(GRADIENT_DELTA, 0, 0)).x - f(p - vec3(GRADIENT_DELTA, 0, 0)).x,
        f(p + vec3(0, GRADIENT_DELTA, 0)).x - f(p - vec3(0, GRADIENT_DELTA, 0)).x,
        f(p + vec3(0, 0, GRADIENT_DELTA)).x - f(p - vec3(0, 0, GRADIENT_DELTA)).x));
}


void main() {
	// TODO: make a Raymarcher!

	vec3 q = vec3((gl_FragCoord.xy / u_Resolution.xy - 0.5), 1.0);
	//float vignette = 1.0 - length(q.xy);
	q.x *= u_Resolution.x / u_Resolution.y;
	q.y -= 0.5;
	vec3 p = vec3(0.0, 0.0, -10.0);
	out_Col = vec4(1.0, 0.5, 0.0, 1.0);
	q = normalize(q);
	q.xz = r(q.xz, u_Time * 0.1);
	p.y += 2.5;
	p.z -= u_Time * 0.5;

	float t = 0.0;
	// d.x: distance; d.y: colorize
	vec3 d = vec3(0.0);
	float steps = 0.0;
	const float maxSteps = 96.0;
	// Ray Marching
	for (float tt = 0.0; tt < maxSteps; ++tt){
		d = f(p + q*t);
		t += d.x*0.45;
		if(!(t<=50.0) || d.x <= Epsilon)
			break;
		steps = tt;
	}

	vec3 glow = vec3(1.1, 1.1, 1.0);
	vec3 fog = vec3(0.7, 0.75, 0.8);
	vec3 color = fog;

    vec3 ldir = normalize(vec3(1.0, 1.0, -1.0));
	vec3 hit = vec3(0.0);
	vec3 normal = vec3(0.0);
	float shadow = 1.0;
	// inside view distance
	if (t <= 50.0){
		hit = p + q*t;
		vec2 delta = vec2(0.001, 0.00);
        // compute normal using dxdy
        normal= vec3( f(hit + delta.xyy).x - f(hit - delta.xyy).x, f(hit + delta.yxy).x - f(hit - delta.yxy).x, f(hit + delta.yyx).x - f(hit - delta.yyx).x);

        normal = normalize(normal);
   		
   		// Need Office Hour
   		shadow = softshadow(hit, ldir, 0.01, 25.0, 32.0);

        float fao = ao(hit, normal);
        vec3 light = (0.5 * color.rgb + vec3(0.5 * fao * abs(dot(normal, ldir)))) * colorize(d.y);
		// rim
		light += (1.0 - t / 50.0) * vec3(fao * pow(1.0 - abs(dot(normal, q)), 4.0)); 

		vec3 reflectDir = reflect(q, normal);
		light += fao * vec3(pow(abs(dot(q, ldir)), 16.0));
		color = min(vec3(1.0), light);
		color *= fao;
	}
	// fog
	color = mix(shadow * color, fog, pow(min(1.0, t / 50.0), 0.5));
	// contrast
	color = smoothstep(0.0, 1.0, color); 
	out_Col = vec4(color, 1.0);
}