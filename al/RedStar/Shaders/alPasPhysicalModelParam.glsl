/**
 * @file	alPasPhysicalModelParam.glsl
 * @author	Matsuda Hirokazu  (C)Nintendo
 *
 * @brief	物理モデルパラメータ
 */
#ifndef AL_PAS_PHYSICAL_MODEL_PARAM_H
#define AL_PAS_PHYSICAL_MODEL_PARAM_H

#include "alPasDefine.glsl"
#include "alMathUtil.glsl"

const float AVERAGE_GROUND_REFLECTANCE = 0.1;

// レイリー散乱の位相関数
float phaseFunctionR(float mu)
{
	return (3.0 / (16.0 * PI)) * (1.0 + mu*mu);
}

// ミー散乱の位相関数
float phaseFunctionM(float mu)
{
	return 1.5 * 1.0 / (4.0 * PI)	// 3/8π
		* (1.0 - mieG2)			// 1-g^2
		* pow(1.0 + mieG2 - 2.0*mieG*mu, -3.0/2.0) * (1.0 + mu*mu)
		/ (2.0 + mieG2);
}

#endif // AL_PAS_PHYSICAL_MODEL_PARAM_H
