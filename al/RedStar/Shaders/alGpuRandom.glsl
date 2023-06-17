/**
 * @file	alGpuRandom.glsl
 * @author	Matsuda Hirokazu  (C)Nintendo
 */
#ifndef GPU_RANDOM_GLSL
#define GPU_RANDOM_GLSL

#include "alMathUtil.glsl"

/**
 *	ノイズ生成に使うランダム関数
 */
float randomForNoise(in vec2 st)
{
	return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}
float randomForNoise(in vec3 stu)
{
	return fract(sin(dot(stu.xyz, vec3(12.9898, 78.233, 343.42))) * 43758.5453123);
}

float r_2(in float n) { return fract(cos(n*89.42)*343.42); }
vec2 randomForNoise2(in vec2 n)
{
 	return vec2(r_2(n.x*23.62 - 300.0 + n.y*34.35), r_2(n.x*45.13 + 256.0 + n.y*38.89)); 
}

#define randomNoise(v2)	randomForNoise(v2)
//#define randomNoise(v2)	randomForNoise2(v2)

/**
 *	Gpu 乱数生成 vec4 n に最初のタネを渡す必要がある。
 *	ピクセル毎に変えたい場合はピクセルを UV として乱数テクスチャから引っ張って n にするとか。
 */
float GpuRandom(inout vec4 n)
{
	const vec4 q = vec4(   1225.0,   1585.0,   2457.0,   2098.0);
	const vec4 r = vec4(   1112.0,    367.0,     92.0,    265.0);
	const vec4 a = vec4(   3423.0,   2646.0,   1707.0,   1999.0);
	const vec4 m = vec4(4194287.0,4194277.0,4194191.0,4194167.0);

	vec4 beta = floor(n/q);
	vec4 p = a * (n - beta * q) - beta * r;
	beta = (sign(-p) + vec4(1.0)) * vec4(0.5) * m;

	n = (p + beta);
	return fract(dot(n/m, vec4(1.0, -1.0, 1.0, -1.0)));
}

/**
 *	@reference : http://www.reedbeta.com/blog/quick-and-easy-gpu-random-numbers-in-d3d11/
 */
uint calcRandXorshift(inout uint rng_state)
{
    // Xorshift algorithm from George Marsaglia's paper
    rng_state ^= (rng_state << 13);
    rng_state ^= (rng_state >> 17);
    rng_state ^= (rng_state << 5);
    return rng_state;
}

/**
 *	[0, 1) の浮動小数にする
 */
float calcGpuRandomXorshift(inout uint rng_state)
{
    return float(calcRandXorshift(rng_state)) * (1.0 / 4294967296.0);
}

/**
 *	seed を作り出すために使う
 *	例：星空
 *		uint seed = calcHashWang(gl_VertexID);
 *		rnd.x = calcGpuRandomXorshift(seed);
 *		rnd.y = calcGpuRandomXorshift(seed);
 *		calcSpherePointPicking(point_pick, rnd.x, rnd.y);
 */
uint calcHashWang(in uint seed)
{
    seed = (seed ^ 61) ^ (seed >> 16);
    seed *= 9;
    seed = seed ^ (seed >> 4);
    seed *= 0x27d4eb2d;
    seed = seed ^ (seed >> 15);
    return seed;
}

/**
 *	二つの乱数を使ってガウス分布の乱数にする
 *	Box-Muller の片方のみ
 */
float makeGpuRandomGauss(in float u1, in float u2)
{
	return sqrt(-2*log(u1)) * cos(2*PI*u2);
}

/**
 *	二つの一様乱数から Box-Muller 変換によって二つのガウス分布乱数を作り出す
 */
 vec2 makeBoxMullerRandomGauss(in float u1, in float u2)
 {
	return vec2(sqrt(-2*log(u1)) * cos(2*PI*u2)
			  , sqrt(-2*log(u2)) * sin(2*PI*u1));
 }

/**
 *	ガウス分布の乱数
 */
float GpuRandomGauss(inout vec4 n)
{
	float u1 = GpuRandom(n);
	float u2 = GpuRandom(n);
	return makeGpuRandomGauss(u1, u2);
}

/**
 *	ランダムな方向を取得
 */
vec3 generateRandomDir(inout vec4 n)
{
	vec2 rnd;
	rnd.x = GpuRandom(n);
	rnd.y = GpuRandom(n);
	rnd.x = 2.0 * PI * rnd.x;
	rnd.y = 2.0 * acos(sqrt(1.0 - rnd.y));

	float sin_x = sin(rnd.x);
	float sin_y = sin(rnd.y);
	vec3 dir;
	dir.x = sin_x * sin_y;
	dir.y = cos(rnd.y);
	dir.z = cos(rnd.x) * sin_y;

	return dir;
}

/**
 *	ディスク上のポイントを取得
 *	渡す値が一様なら一様なポイント群になる
 *	x = r cosθ, y = r sinθ では一様にならない
 *	x = √r cosθ,y = √r sinθ が一様になる
 *	参考：Wolfram Math World
 */
vec2 calcDiskPointPicking(in float r_0_1, in float theta_0_1)
{
	float root_r = sqrt(r_0_1);
	float theta = theta_0_1 * PI * 2.0;
	float cos = cos(theta);
	float sin = sin(theta);
	return vec2(root_r * cos, root_r * sin);
}

/**
 *	単位ディスク上の一様なポイントを取得
 */
vec2 generateDiskPointPicking(inout vec4 n)
{
	return calcDiskPointPicking(GpuRandom(n), GpuRandom(n));
}

#endif // GPU_RANDOM_GLSL
