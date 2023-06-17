/**
 * @file	alWrapLightingFunction.glsl
 * @author	Yosuke Mori  (C)Nintendo
 *
 * @brief	ラップライティング関数
 */

#ifndef WRAP_LIGHTING_FUNCTION_GLSL
#define WRAP_LIGHTING_FUNCTION_GLSL

/**
 *	Half-Lambert
 */
#define	calcNLrawNLwrapHL()						\
	float N_L_wrap_tmp = N_L_raw*0.5 + 0.5;		\
	float N_L_wrap = N_L_wrap_tmp*N_L_wrap_tmp;	\

/**
 *	Half-Lambert 差分
 */
float calcWrapLightingDiff(in float N_L_raw, in float wrap_coef)
{
	calcNLrawNLwrapHL();
	return clamp01(N_L_wrap - clamp01(N_L_raw)) * wrap_coef;
}

/**
 *	Half-Lambert
 */
float calcWrapLighting(in float N_L_raw, in float wrap_coef)
{
	calcNLrawNLwrapHL();
	return clamp01(N_L_wrap - clamp01(N_L_raw)) * wrap_coef + clamp01(N_L_raw);
}

#endif // WRAP_LIGHTING_FUNCTION_GLSL
