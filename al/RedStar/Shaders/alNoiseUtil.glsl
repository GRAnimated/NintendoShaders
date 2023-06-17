/**
 * @file	alNoiseUtil.glsl
 * @author	Matsuda Hirokazu  (C)Nintendo
 *
 * @brief	ノイズテクスチャ生成で使うユーティリティ
 *			random の新しいバージョンがあるので alMathUtil との関連を考える必要あり
 */
#ifndef AL_NOISE_UTIL_GLSL
#define AL_NOISE_UTIL_GLSL

#include "alGpuRandom.glsl"

/**
 *	中心差分計算用
 */
const float e = 0.01;
const vec3 dx = vec3( e   , 0.0 , 0.0 );
const vec3 dy = vec3( 0.0 , e   , 0.0 );
const vec3 dz = vec3( 0.0 , 0.0 , e   );

/**
 *	ノイズで共通に使う Ubo
 */
BINDING_UBO_OTHER_FIRST uniform NoiseCommonUbo
{
	vec4 	uResolutionData;	// xyz : inv resolution, w : resolution.x / resolution.y
	vec4	uTestData;			// x : Time,  w : Debug Scale
	vec4 	uCoordScale;		// xyz : coord scale		
	vec4	uData;
	vec4	uData2;
	vec4	uData3;
	vec2	uSphereCurveTonePowerSlope;	// x : power,  y : slope
	vec4	uSphereCurvePeakPosPowerIntensity;	// x : pos,  y : power,  z : intensity
};

#define INV_RESOLUTION_XY	uResolutionData.xy
#define INV_RESOLUTION_Z	uResolutionData.z
#define RES_X_DIV_RES_Y		uResolutionData.w
#define TIME				uTestData.x
#define DEBUG_SCALE			uTestData.w

float calcNoise(in vec2 st)
{
	vec2 i = floor(st);
	vec2 f = fract(st);

	// 4 corners
	float a = randomNoise(i);
	float b = randomNoise(i + vec2(1.0, 0.0));
	float c = randomNoise(i + vec2(0.0, 1.0));
	float d = randomNoise(i + vec2(1.0, 1.0));

	// Smooth Interpolation
	// Cubic Hermine Curve.  Same as SmoothStep()
	vec2 u = f * f * (3.0 - 2.0 * f);

	// Mix 4 coorners porcentages
	return mix(a, b, u.x) + (c-a)*u.y*(1.0-u.x) + (d-b)*u.x*u.y;
}

vec3 hash33(in vec3 p3)
{
	p3 = fract(p3 * vec3(.1031,.11369,.13787));
	p3 += dot(p3, p3.yxz+19.19);
	return -1.0 + 2.0 * fract(vec3((p3.x + p3.y)*p3.z, (p3.x+p3.z)*p3.y, (p3.y+p3.z)*p3.x));
}

#ifndef NUM_OCTAVES
	#define NUM_OCTAVES	(5)
#endif // NUM_OCTAVES

#if 0
float fBm(in vec2 p)
{
	float t = 0.0;
	float inv_freq = 1.0;
	const float per  = 0.5;

	#if (IS_FBM_ROTATE == 1)
	const vec2 shift = vec2(100.0);
	// Rotate to reduce axial bias
	const mat2 rot = mat2(cos(0.5), sin(0.5), -sin(0.5), cos(0.50));
	#endif // IS_FBM_ROTATE

	for (int i=0; i<NUM_OCTAVES; ++i)
	{
		float amp  = pow(per, float(NUM_OCTAVES - i));
		t += calcNoise(p) * amp;

		#if (IS_FBM_ROTATE == 1)
		p = rot * p * inv_freq + shift;
		#else
		p *= inv_freq;
		#endif // IS_FBM_ROTATE

		inv_freq *= 0.5;
	}
	return t;
}
#else
float fBm(in vec2 st)
{
	// Initial values
	float value = 0.0;
	float amplitud = .5;
	float frequency = 0.;
	//
	// Loop of octaves
	for (int i = 0; i < NUM_OCTAVES; i++)
	{
		value += amplitud * calcNoise(st);
		st *= 2.;
		amplitud *= .5;
	}
	return value;
}
#endif

/**
 *	シームレス fBm
 */
float fBmSeamless(vec2 p, vec2 q, vec2 r)
{
	return 	fBm(vec2(p.x,       p.y      )) *        q.x  *        q.y  +
			fBm(vec2(p.x,       p.y + r.y)) *        q.x  * (1.0 - q.y) +
			fBm(vec2(p.x + r.x, p.y      )) * (1.0 - q.x) *        q.y  +
			fBm(vec2(p.x + r.x, p.y + r.y)) * (1.0 - q.x) * (1.0 - q.y);
}

#define MakeSeamless(uv, C, func)									\
	( func(uv) 							* (C.x-uv.x) * (C.y-uv.y)	\
	+ func(vec2(uv.x-C.x, 	uv.y)) 		* uv.x * (C.y-uv.y)			\
	+ func(vec2(uv.x-C.x, 	uv.y-C.y)) 	* uv.x * uv.y				\
	+ func(vec2(uv.x, 		uv.y-C.y)) 	* (C.x-uv.x) * uv.y)		\
	/ (C.x*C.y)


#define MakeSeamless2(func, p, q, r)										\
	func(vec2(p.x,       p.y      )) *        q.x  *        q.y  +			\
	func(vec2(p.x,       p.y + r.y)) *        q.x  * (1.0 - q.y) +			\
	func(vec2(p.x + r.x, p.y      )) * (1.0 - q.x) *        q.y  +			\
	func(vec2(p.x + r.x, p.y + r.y)) * (1.0 - q.x) * (1.0 - q.y)

/**
 *	テクスチャフェッチ版 fBm テクスチャは seamless が良い
 */
float fBmTexture(in vec2 st, sampler2D tex)
{
	// Initial values
	float value = 0.0;
	float amplitud = 1.0;
	float frequency = 0.;
	//
	// Loop of octaves
	for (int i = 0; i < NUM_OCTAVES; i++)
	{
		value += amplitud * (texture(tex, st).r * 2 - 1);
		st *= 2.;
		amplitud *= .5;
	}
	return value;
}
#endif // AL_NOISE_UTIL_GLSL
