/**
 * @file	alEnvBrdfUtil.glsl
 * @author	Matsuda Hirokazu  (C)Nintendo
 *
 * @brief	BRDF 関連ユーティリティ
 */
#define ENV_DFG_TYPE		(1)
#define ENV_DFG_LAZAROV		(0)
#define ENV_DFG_POLYNOMIAL	(1)

/**
 *	ラフネスリマップ
 *	gloss = (1 - roughness)^4
 *	gloss = (1 - roughness*0.7)^6  --- Crytek in Ryse
 */
#define ROUGHNESS_REMAP(roughness)	\
	float gloss = 1 - roughness;	\
	gloss *= gloss;					\
	gloss *= gloss;

/**
 *	IBL 用解析的 DFG
 *	Environment BRDF or Ambient BRDF
 */
void calcEnvDFGLazarov(out vec3 reflectance, in vec3 F0, in float roughness, in float N_V)
{
	ROUGHNESS_REMAP(roughness);
	vec4 p0 = vec4(0.5745,  1.548,  -0.02397, 1.301);
	vec4 p1 = vec4(0.5753, -0.2511, -0.02066, 0.4755);
	vec4 t = gloss * p0 + p1;
	float bias  = clamp01(t.x * min(t.y, exp2(-7.672 * N_V)) + t.z);
	float delta = clamp01(t.w);
	float scale = delta - bias;
	bias *= clamp01(50.0 * F0.g);
	reflectance = F0 * scale + bias;
}

/**
 *	さらに正確なフィッティングを施したもの
 */
void calcEnvDFGPolynomial(out vec3 reflectance, in vec3 F0, in float roughness, in float N_V)
{
	ROUGHNESS_REMAP(roughness);
	float x = gloss;
	float y = N_V;

	float b1 = -0.1688;
	float b2 =  1.895;
	float b3 =  0.9903;
	float b4 = -4.853;
	float b5 =  8.404;
	float b6 = -5.069;

	float d0 = 0.6045;
	float d1 = 1.699;
	float d2 = -0.5228;
	float d3 = -3.603;
	float d4 = 1.404;
	float d5 = 0.1939;
	float d6 = 2.661;
	#if 0
	float x2 = x*x;
	float y2 = y*y;
	float bias  = clamp01(min( b1*x + b2*x*x, b3 + b4*y + b5*y2 + b6*y2*y));
	float delta = clamp01(d0 + d1*x + d2*y + d3*x2 + d4*x*y + d5*y2 + d6*x2*x);
	#else
	// こうした方が ALU 減る？
	float bias  = clamp01(min( x*(b1 + b2*x), b3 + y*(b4 + y*(b5 + b6*y))));
	float delta = clamp01(d0 + y*(d2 + d5*y) + x*(d1 + x*(d3 + d6*x) + d4*y));
	#endif

	float scale = delta - bias;
	bias *= clamp01(50.0*F0.g);
	reflectance = F0 * scale + bias;
}

void calcEnvDFG(out vec3 reflectance, in vec3 F0, in float roughness, in float N_V)
{
#if (ENV_DFG_TYPE == ENV_DFG_LAZAROV)
	calcEnvDFGLazarov(reflectance, F0, roughness, N_V);
#elif (ENV_DFG_TYPE == ENV_DFG_POLYNOMIAL)
	calcEnvDFGPolynomial(reflectance, F0, roughness, N_V);
#endif
}
