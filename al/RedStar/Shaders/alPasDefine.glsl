/**
 * @file	alPasDefine.glsl
 * @author	Matsuda Hirokazu  (C)Nintendo
 *
 * @brief	事前計算大気散乱の定数など
 */

#ifndef PAS_DEFINE_WUSL
#define PAS_DEFINE_WUSL

//H = sqrt(Rt*Rt - Rg*Rg) = sqrt(766800);
const float H = 875.67117115958545183996498359145;

const float HR		= 8.0;
const float invHR	= 1.0 / HR;
const vec3 betaR	= vec3(5.8e-3, 1.35e-2, 3.31e-2);

const float HM		= 1.2;
const float invHM	= 1.0 / HM;
const vec3 betaMSca	= vec3(4e-3);
//const vec3 betaMSca	= vec3(20e-3); // clear sky
const vec3 betaMEx	= betaMSca / 0.9;
const float mieG	= 0.8;
//const float mieG	= 0.76; // clear sky
const float mieG2	= mieG*mieG;

#endif // PAS_DEFINE_WUSL

