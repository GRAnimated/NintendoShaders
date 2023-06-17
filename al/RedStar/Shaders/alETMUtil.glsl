/**
 * @file	alETMUtil.glsl
 * @author	Matsuda Hirokazu  (C)Nintendo
 *
 * @brief	ETM(Extinction Transmittance Maps) ユーティリティ
 */

#ifndef ETM_UTIL_GLSL
#define ETM_UTIL_GLSL

#include "alMathUtil.glsl"

/**
 *	ETM への変換行列
 */
struct EtmMtx
{
	vec4	uToETMMtx[4];		// ETM のテクスチャへの射影行列
	vec4	uFetchETMMtx[4];	// ETM のテクスチャをフェッチする行列
	vec4	uProjInfo;			// View 空間の x : Near,  y : Far,  z : (Far-Near),  w : Inv Range
};

#define ETM_NEAR(var)		var.uProjInfo.x
#define ETM_FAR(var)		var.uProjInfo.y
#define ETM_RANGE(var)		var.uProjInfo.z
#define ETM_INV_RANGE(var)	var.uProjInfo.w

/**
 *	パーティクル雲レンダリングで使う Ubo
 */
layout(std140) uniform EtmUbo
{
	vec4 	uTexInfo;			// xy : 1/tex resolution
	vec4 	uDistData;			// x : distance scale,  y : camera to near distance,  z : transmittance exp scale
	float	uDctWeight[4];		// each j-th coefficient normalize factor
	vec4	uDctData;			// x : Draw DCT Scale
};

#define DIST_SCALE					uDistData.x
#define CAM_TO_NEAR_DIST			uDistData.y
#define TRANSMITTANCE_EXP_SCALE		uDistData.z
#define INV_ETM_TEX_RESO			uTexInfo.xy
#define DRAW_DCT_SCALE				uDctData.x

/**
 *	レンダリングした Traversal Distance の min, max を取得する（正規化されている）
 */
void getTraversalStartEnd(out vec2 start_end, in vec2 uv, sampler2D tex)
{
	vec2 fetch = texture(tex, uv).rg;
	start_end = vec2(1 - fetch.r, fetch.g);
}

/**
 *	ETM の DCT 係数を計算する
 */
void calcEtmDctCoefficient(out vec4 dct_coef, in float x, in float d, in float d_max, in float extinction, float weight[4])
{
	float inv_dmax = 1.0 / d_max;
	float pi_div_2dmax = PI * inv_dmax*0.5;
	float c[4];
	for (int i=0; i<4; ++i)
	{
		int j = i+1; // 係数 j は０にはならない 
		float b = weight[i] * cos((2*x+1)*j*pi_div_2dmax);
		c[i] = inv_dmax * (d * extinction * b);
	}
	dct_coef = vec4(c[0], c[1], c[2], c[3]);
}

/**
 *	ETM の DCT 係数からトランスミッタンスを計算する
 */
void calcTransmittanceByEtm4(out float T, in vec4 dct_coef, in float x, in float d_max, in float exp_scale, float weight[4])
{
	float pi_div_2dmax = PI / (2*d_max);
	float d_max_div_pi = d_max * INV_PI;
	float B[4];
	for (int i=0; i<4; ++i)
	{
		int j = i+1;
		B[i] = (weight[i] * d_max_div_pi/j) * (sin((1+2*x)*j*pi_div_2dmax) - sin(j*pi_div_2dmax));
	}
	T = clamp01(exp(-exp_scale*(dct_coef.x*B[0] + dct_coef.y*B[1] + dct_coef.z*B[2] + dct_coef.w*B[3])));
}

#endif // ETM_UTIL_GLSL
