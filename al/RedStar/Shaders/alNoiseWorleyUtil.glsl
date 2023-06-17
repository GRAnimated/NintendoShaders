/**
 * @file	alNoiseWorleyUtil.glsl
 * @author	Matsuda Hirokazu  (C)Nintendo
 *
 * @brief	Worley Noise
 */
#ifndef AL_NOISE_WORLEY_UTIL_GLSL
#define AL_NOISE_WORLEY_UTIL_GLSL

#include "alMathUtil.glsl"

/**
 *	V3f -> V3f マッピングのランダム関数
 */
vec3 random3(in vec3 c)
{
	float j = 4096.0 * sin(dot(c, vec3(17.0, 59.4, 15.0)));
	vec3 r;
	r.z = fract(512.0*j); j *= 0.125;
	r.x = fract(512.0*j); j *= 0.125;
	r.y = fract(512.0*j);
	return r;
}

float random3to1(in vec3 c)
{
	c += vec3(74.2, -124.5, 99.4);
	float j = 4096.0 * sin(dot(c, vec3(17.0, 59.4, 15.0)));
	return fract(j);
}

#ifndef IS_USE_MANHATTAN_DIST
	#define IS_USE_MANHATTAN_DIST	0
#endif

/**
 *	距離を計算
 */
float calcDist(in vec3 p1, in vec3 p2)
{
	#if (IS_USE_MANHATTAN_DIST == 0)
		return distance(p1, p2);
	#elif (IS_USE_MANHATTAN_DIST == 1)
		return abs(p1.x-p2.x) + abs(p1.y-p2.y) + abs(p1.z-p2.z);
	#endif
}

/**
 *	３Ｄ Worley ノイズ。シームレス可
 */
float calcWorleyNoise3D(in vec3 stu, in vec3 rep, in float dist_offset_scale)
{
	vec3 i_stu = floor(stu);
	vec3 f_stu = fract(stu);
	float dist = 1.0;

	for (int z=-1; z<=1; ++z)
	for (int y=-1; y<=1; ++y)
	for (int x=-1; x<=1; ++x)
	{
		vec3 offset = vec3(x, y, z); // 隣へのオフセット
		vec3 rnd_idx = mod(i_stu + offset, rep); // 格子毎に点を求めるための元となるベクトル。格子毎に一意
		vec3 random01 = random3(rnd_idx); // ランダムベクトル。[0, 1]の範囲だが f_stu も[0, 1]なので[-1, 1]にしなくても良い
		float dist_offset = random3to1(random01)*dist_offset_scale;
		vec3 neighbor_pt = random01 + offset;
		float n_dist = calcDist(neighbor_pt, f_stu);
		dist = min(dist, n_dist + dist_offset);
	}
	return 1.0 - clamp01(dist);
}

/**
 *	線分との距離
 */
float calcDistToLine(in vec3 begin, in vec3 end, in vec3 point)
{
	vec3 s_e = end - begin;
	vec3 s_p = point - begin;
	vec3 e_p = point - end;
	
	// pointが始点側
	float e = dot(s_p, s_e);
	if (e <= 0.0) { return sqrt(dot(s_p, s_p)); }
	
	// pointが終点側
	float f = dot(s_e, s_e);
	if (e >= f) { return sqrt(dot(e_p, e_p)); }
	
	// 間にある
	return sqrt(max(0.0, dot(s_p, s_p) - e * (e / f)));
}

float calcSphereCurve(in float value)
{
	#if 1
	float tone_pow = uSphereCurveTonePowerSlope.x;	float tone_slope = uSphereCurveTonePowerSlope.y;
	float tone = pow(value, tone_pow)*tone_slope;

//	float peak_pos_param = 1.0;	float peak_pow_param = 5.0;	float peak_intensity_param = -0.25;
	float peak_pos_param = uSphereCurvePeakPosPowerIntensity.x;
	float peak_pow_param = uSphereCurvePeakPosPowerIntensity.y;
	float peak_intensity_param = uSphereCurvePeakPosPowerIntensity.z;

	float peak_pos = clamp01(value - peak_pos_param);
	float peak = exp2(-peak_pos*peak_pos*100.0*peak_pow_param)*peak_intensity_param;
	value = clamp01(tone + peak);
	#endif // 0
	return value;
}


/**
 *	Worley の要領で線分との距離を計算する
 */
float calcThinWorleyNoise3D(in vec3 stu, in vec3 rep, in vec3 rnd_offset, in float line_scale, in float dist_offset_scale)
{
	vec3 i_stu = floor(stu);
	vec3 f_stu = fract(stu);
	float dist = 1.0;

	const int cRange = 3;
	for (int z=-cRange; z<=cRange; ++z)
	for (int y=-cRange; y<=cRange; ++y)
	for (int x=-cRange; x<=cRange; ++x)
	{
		vec3 offset = vec3(x, y, z); // 隣へのオフセット
		vec3 rnd_idx = mod(i_stu + offset + (random3(rnd_offset)), rep); // 格子毎に点を求めるための元となるベクトル。格子毎に一意
		vec3 random01 = random3(rnd_idx); // ランダムベクトル。[0, 1]の範囲だが f_stu も[0, 1]なので[-1, 1]にしなくても良い
		vec3 random02 = random3(random01);
		float dist_offset = random3to1(random01)*random3to1(random02)*dist_offset_scale;
		vec3 neighbor_line_end		= random01*line_scale + offset;
		vec3 neighbor_line_begin	= random02*line_scale + offset;
		float n_dist = calcDistToLine(neighbor_line_begin, neighbor_line_end, f_stu);
		n_dist = calcSphereCurve(n_dist);
		dist = min(dist, n_dist + dist_offset);
	}
	dist = clamp01(dist);

	return dist;
}


#endif // AL_NOISE_WORLEY_UTIL_GLSL
