/**
 * @file	alNoisePerlinUtil.glsl
 * @author	Matsuda Hirokazu  (C)Nintendo
 *
 * @brief	パーリンノイズユーティリティ
 */
#ifndef AL_NOISE_PERLIN_UTIL_GLSL
#define AL_NOISE_PERLIN_UTIL_GLSL

#include "alNoiseUtil.glsl"

#if 1
	#define mod289core(x)	mod(x, 289.0)
#else
	#define mod289core(x)	(x - floor(x * (1.0/289.0)) * 289.0)
#endif

float mod289(in float x) { return mod289core(x); }
vec3  mod289(in vec3  x) { return mod289core(x); }
vec4  mod289(in vec4  x) { return mod289core(x); }

float mod12(in float x) { return mod(x, 12.0); }
vec3  mod12(in vec3  x) { return mod(x, 12.0); }
vec4  mod12(in vec4  x) { return mod(x, 12.0); }

/**
 *	順列多項式
 *	整数ー＞整数のマッピングによって
 *	整数列をシャッフルされた整数列にしたいときに使う
 */
vec4  permute289(in vec4  x) { return mod289( ((x*34.0)+1.0)*x ); }
vec3  permute289(in vec3  x) { return mod289( ((x*34.0)+1.0)*x ); }
float permute289(in float x) { return mod289( ((x*34.0)+1.0)*x ); }

/**
 *	6x^2 + x mod 12
 */
vec4  permute12(in vec4  x) { return mod12( ((x*34.0)+1.0)*x ); }
vec3  permute12(in vec3  x) { return mod12( ((x*34.0)+1.0)*x ); }
float permute12(in float x) { return mod12( ((x*34.0)+1.0)*x ); }

/**
 *	inversesqrt のテイラー展開近似
 */
vec4 taylorInvSqrt(in vec4 r){ return 1.79284291400159 - 0.85373472095314 * r; }

/**
 *	補間式とその微分形式
 *	f(x) 	= 6x^5 - 15x^4 + 10x^3
 *	f'(x)	= 30x^4 - 60x^3 + 30x^2
 *	f"(x)	= 120x^3 - 180x^2 + 60x
 */
float interp(in float t) 		{ return t*t*t*(t*(t*  6.0 -  15.0) + 10.0); }
float interp_dash(in float t) 	{ return   t*t*(t*(t* 30.0 -  60.0) + 30.0); }
float interp_dash2(in float t) 	{ return     t*(t*(t*120.0 - 180.0) + 60.0); }

vec3 calcGradientVector(in vec3 p, in vec3 rep)
{
	#if 1
	vec3 nrm_p = floor(289.0 * p / rep);
	#else
	vec3 nrm_p = p;
	#endif

	vec3 shuffle289 = permute289(permute289(nrm_p.yzx + p.zxy + nrm_p.xzy));
	#if 1
	vec3 nrm_289 = (shuffle289/289.0) * 2.0 - 1.0; // [-1, 1] に変換
	#else
	vec3 nrm_289 = fract(shuffle289/41.0) * 2.0 - 1.0; // [-1, 1] に変換
	#endif
	float w = 1.5 - abs(nrm_289.x) - abs(nrm_289.y) - abs(nrm_289.z);
	if (0.0 < w)
	{
		return nrm_289;
	}
	else
	{
		return vec3(nrm_289.x - sign(nrm_289.x)
				  , nrm_289.y - sign(nrm_289.y)
				  , nrm_289.z - sign(nrm_289.z));
	}
}

/**
 *	3D パーリンノイズ（シームレス対応）
 *	xyz : 各偏微分成分,  w : ノイズ値
 */
vec4 noisePerlin3D(in vec3 P, in vec3 rep)
{
	vec3 Pi0 = mod289(mod(floor(P), rep));

	// グラディエント
#if 0
	vec3 g000 = calcGradientVector(mod(Pi0 + vec3(0,0,0), rep), rep);
	vec3 g100 = calcGradientVector(mod(Pi0 + vec3(1,0,0), rep), rep);
	vec3 g010 = calcGradientVector(mod(Pi0 + vec3(0,1,0), rep), rep);
	vec3 g110 = calcGradientVector(mod(Pi0 + vec3(1,1,0), rep), rep);
	vec3 g001 = calcGradientVector(mod(Pi0 + vec3(0,0,1), rep), rep);
	vec3 g101 = calcGradientVector(mod(Pi0 + vec3(1,0,1), rep), rep);
	vec3 g011 = calcGradientVector(mod(Pi0 + vec3(0,1,1), rep), rep);
	vec3 g111 = calcGradientVector(mod(Pi0 + vec3(1,1,1), rep), rep);
	#if 0
	g000 = normalize(g000);
	g100 = normalize(g100);
	g010 = normalize(g010);
	g110 = normalize(g110);
	g001 = normalize(g001);
	g101 = normalize(g101);
	g011 = normalize(g011);
	g111 = normalize(g111);
	#endif
#else
	vec3 g000 = normalize(hash33(mod(Pi0 + vec3(0,0,0), rep)));
	vec3 g100 = normalize(hash33(mod(Pi0 + vec3(1,0,0), rep)));
	vec3 g010 = normalize(hash33(mod(Pi0 + vec3(0,1,0), rep)));
	vec3 g110 = normalize(hash33(mod(Pi0 + vec3(1,1,0), rep)));
	vec3 g001 = normalize(hash33(mod(Pi0 + vec3(0,0,1), rep)));
	vec3 g101 = normalize(hash33(mod(Pi0 + vec3(1,0,1), rep)));
	vec3 g011 = normalize(hash33(mod(Pi0 + vec3(0,1,1), rep)));
	vec3 g111 = normalize(hash33(mod(Pi0 + vec3(1,1,1), rep)));
#endif

	// 以下、Pf を使うもの。つまり微分計算で考慮すべきもの
	vec3 Pf0 = fract(P);
	float n000 = dot(g000, Pf0 - vec3(0,0,0));
	float n100 = dot(g100, Pf0 - vec3(1,0,0));
	float n010 = dot(g010, Pf0 - vec3(0,1,0));
	float n110 = dot(g110, Pf0 - vec3(1,1,0));
	float n001 = dot(g001, Pf0 - vec3(0,0,1));
	float n101 = dot(g101, Pf0 - vec3(1,0,1));
	float n011 = dot(g011, Pf0 - vec3(0,1,1));
	float n111 = dot(g111, Pf0 - vec3(1,1,1));

	float du = interp_dash(Pf0.x);
	float dv = interp_dash(Pf0.y);
	float dw = interp_dash(Pf0.z);
	float  u = interp(Pf0.x);
	float  v = interp(Pf0.y);
	float  w = interp(Pf0.z);
	float uv = u*v; float vw = v*w; float uw = u*w; float uvw = uv*w;
	// xyz : nXXX の各偏微分,  w : nXXX
	vec4 a = vec4(g000, n000);
	vec4 b = vec4(g100, n100);
	vec4 c = vec4(g010, n010);
	vec4 d = vec4(g110, n110);
	vec4 e = vec4(g001, n001);
	vec4 f = vec4(g101, n101);
	vec4 g = vec4(g011, n011);
	vec4 h = vec4(g111, n111);
	vec4 k0 =  a;
	vec4 k1 =  b-a;
	vec4 k2 =  c-a;
	vec4 k3 =  e-a;
	vec4 k4 =  a-b-c+d;
	vec4 k5 =  a-c-e+g;
	vec4 k6 =  a-b-e+f;
	vec4 k7 = -a+b+c-d+e-f-g+h;

	vec4 ret;
	ret.w = k0.a + k1.a*u + k2.a*v + k3.a*w + k4.a*uv + k5.a*vw + k6.a*uw + k7.a*uvw;
	ret.x = k0.x + k1.x*u + k1.a*du + k2.x*v + k3.x*w
			+ k4.x*uv + k4.a*du*v + k5.x*vw
			+ k6.x*uw + k6.a*du*w + k7.x*uvw + k7.a*du*vw;
	ret.y = k0.y + k1.y*u + k2.y*v + k2.a*dv + k3.y*w
			+ k4.y*uv + k4.a*u*dv + k5.y*vw + k5.a*dv*w
			+ k6.y*uw + k7.y*uvw + k7.a*uw*dv;
	ret.z = k0.z + k1.z*u + k2.z*v + k3.z*w + k3.a*dw
			+ k4.z*uv + k5.z*vw + k5.a*v*dw + k6.z*uw + k6.a*u*dw
			+ k7.z*uvw + k7.a*uv*dw;

	ret *= 2.2; // 謎の係数。これが無いとちょっと薄い
	return ret;
}

/**
 *	パーリンノイズでベクトル場を作り出すコア関数
 */
void calcNoiseVec3(out vec4 Ax, out vec4 Ay, out vec4 Az, in vec3 x, in vec3 dx, in vec3 rep)
{
	Ax = noisePerlin3D(vec3(x) + dx, rep);
	Ay = noisePerlin3D(vec3(x.y - 19.1, x.z +  33.4, x.x + 47.2) + dx, rep);
	Az = noisePerlin3D(vec3(x.z + 74.2, x.x - 124.5, x.y + 99.4) + dx, rep);
}

/**
 *	パーリンノイズでベクトル場を作り出す
 */
vec3 noiseVec3(in vec3 x, in vec3 dx, in vec3 rep)
{
	vec4 Ax, Ay, Az;
	calcNoiseVec3(Ax, Ay, Az, x, dx, rep);
	return vec3(Ax.w, Ay.w, Az.w);
}

/**
 *	パーリンノイズでベクトル場を作り出してその偏微分から回転rotを計算する
 */
vec3 noiseVec3Rot(in vec3 x, in vec3 rep)
{
	vec4 Ax, Ay, Az;
	calcNoiseVec3(Ax, Ay, Az, x, vec3(0.0), rep);
	return vec3(Az.y - Ay.z, Ax.z - Az.x, Ay.x - Ax.y);
}

/**
 *	カールノイズ
 */
vec3 calcCurlNoisePerlin3D(in vec3 p, in vec3 rep)
{
	#if 0 // 中心差分
	vec3 p_x0 = noiseVec3(p, -dx, rep);
	vec3 p_x1 = noiseVec3(p, +dx, rep);
	vec3 p_y0 = noiseVec3(p, -dy, rep);
	vec3 p_y1 = noiseVec3(p, +dy, rep);
	vec3 p_z0 = noiseVec3(p, -dz, rep);
	vec3 p_z1 = noiseVec3(p, +dz, rep);

	float x = (p_y1.z - p_y0.z) - (p_z1.y - p_z0.y);
	float y = (p_z1.x - p_z0.x) - (p_x1.z - p_x0.z);
	float z = (p_x1.y - p_x0.y) - (p_y1.x - p_y0.x);
	const float divisor = 1.0 / (2.0 * e);
	return vec3(x, y, z) * divisor;
	#else
	vec3 rot = noiseVec3Rot(p, rep);
	return rot;
	#endif
}

/**
 *	パーリンノイズの fBm
 */
#ifndef PERLIN_FBM_OCTAVES
	#define PERLIN_FBM_OCTAVES 3
#endif // PERLIN_FBM_OCTAVES

float noisePerlin3DfBm(in vec3 P, in vec3 rep)
{
	vec3 stu = P;
	float n = 0.0;
	float a = 0.5;
	for (int i=0; i<PERLIN_FBM_OCTAVES; ++i)
	{
		float nz = noisePerlin3D(stu, rep).w;
		n += a * nz;
		stu *= 2.0;
		rep *= 2.0;
		a *= 0.5;
	}
	return n;
}

#endif // AL_NOISE_PERLIN_UTIL_GLSL
