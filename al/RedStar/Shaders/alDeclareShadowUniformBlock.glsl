/**
 * @file	alDeclareShadowUniformBlock.glsl
 * @author	Musa Kazuhiro  (C)Nintendo
 *
 * @brief	ShadowUBO 定義
 */

#ifndef AL_DECLARE_SHADOW_UNIFORM_BLOCK_GLSL
#define AL_DECLARE_SHADOW_UNIFORM_BLOCK_GLSL

BINDING_UBO_OTHER_FIRST uniform StaticDepthShadow // @@ id="cStaticDepthShadow"
{
	vec4	cCubeWorldViewProj[ 4 ];
	vec4	cCubeInvWorldView[ 4 ];
	vec4	cShadowMatrix[ 4 ];
	float	cEsmC;
	float	cZPow;
	float	cShadowCenterZ;
	float	cShadowWidthZ;
	float	cShadowWidthZGradation;
	float	cShadowWidthXY;
	float	cShadowDensity;
};

#endif //AL_DECLARE_SHADOW_UNIFORM_BLOCK_GLSL
