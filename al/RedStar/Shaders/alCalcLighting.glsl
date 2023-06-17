/**
 * @file	alCalcLighting.glsl
 * @author	Matsuda Hirokazu  (C)Nintendo
 *
 * @brief	ライティング計算
 */

/**
 *	ディフューズ反射計算
 */
float calcDiffuseIntensity(in vec3 nrm, in vec3 to_light)
{
	// 正規化ディフューズ
	return clamp01(dot(nrm, to_light)) * INV_PI;
}

/**
 *	ラップライティング
 */
float calcWrapDiffuse(in vec3 nrm, in vec3 to_light, in vec2 wrap_coef)
{
	float N_L = dot(nrm, to_light);
	return clamp01((N_L + wrap_coef.x) * wrap_coef.y) * INV_PI;
}

/**
 *	緩やかなカーブにしてみる
 */
float calcWrapDiffuseInterp(in vec3 nrm, in vec3 to_light, in vec2 wrap_coef)
{
	float N_L = dot(nrm, to_light);
	float t = (N_L + 1) * 0.5;
	float wrap = clamp01(((t * wrap_coef.x + 1.0) * N_L + wrap_coef.x * (1-t)) * wrap_coef.y);
	return wrap * INV_PI;
}

/**
 *	RenderMaterial で使う、ラップライティングと通常のライティングの差を求める
 *	@fixme
 *	wrap_coef = x : 1/(1+wrap)  y : wrap/(1+wrap) にして mull add にした方が速い
 */
float calcDiffWrapDiffuse(in vec3 nrm, in vec3 to_light, in vec2 wrap_coef)
{
	float N_L = dot(nrm, to_light);
	float wrap_N_L = clamp01((N_L + wrap_coef.x) * wrap_coef.y);
	return (wrap_N_L - clamp01(N_L)) * INV_PI;
}

/**
 *	緩やかなカーブにしてみる
 */
float calcDiffWrapDiffuseInterp(in vec3 nrm, in vec3 to_light, in vec2 wrap_coef)
{
	float N_L = dot(nrm, to_light);
	float t = (N_L + 1) * 0.5;
	float wrap = clamp01(((t * wrap_coef.x + 1.0) * N_L + wrap_coef.x * (1-t)) * wrap_coef.y);
	return (wrap - clamp01(N_L)) * INV_PI;
}
