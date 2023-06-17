/**
 * @file	alLppLineLight.glsl
 * @author	Yosuke Mori  (C)Nintendo
 *
 * @brief	ライトプリパスの線分ライト
 */
 
#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable
#endif

#define LPP_ENABLE_SPECULAR	(0)
#define LPP_ENABLE_DISCARD	(0)
#define IS_USE_SPHERE_GGX_SPECULAR_NORMALIZE (0)

#include "agl_lightprepass.shinc"
#include "alMathUtil.glsl"
#include "alLightingFunction.glsl"
#include "alDefineVarying.glsl"
#include "alLppDeclareSampler.glsl"
#include "alGBufferUtil.glsl"
#include "alCalcNormal.glsl"

// 光源の種類で共通
BINDING_SAMPLER_BASECOLOR		uniform sampler2D	uBaseColor;
BINDING_SAMPLER_NORMAL			uniform sampler2D	uNrmMotion;
BINDING_SAMPLER_LINEAR_DEPTH	uniform sampler2D	uViewLinearDepth;

DECLARE_NOPERS_VARYING(vec2,	vTexCoord);
DECLARE_NOPERS_VARYING(vec3,	vScreen);

/**
 *	ライトプリパスから取得できるUBO型
 */
layout(std140) uniform Context
{
	LPP_UBO_LAYOUT_CONTEXT
};

/**
 *	ラインライト
 */
layout(std140) uniform LineLightView
{
	LineLight	uLineLight;
	vec4		uPVWMtx[4];
};

// -----------------------------------------
#if defined	(AGL_VERTEX_SHADER)

layout(location=0) in vec3 aPosition;

void main()
{
	gl_Position = multMtx44Vec3(uPVWMtx, aPosition);

	// チラつき対策。シャドウマスクと同じ方法
	{
		float sign_w = sign(gl_Position.w);
		float abs_w  = abs(gl_Position.w);

		abs_w = max( abs_w, 32 );
		gl_Position.w = sign_w*abs_w;
	}
	
	calcScreenCoord(vScreen, vTexCoord, gl_Position, cLppContext_TanFovyHalf, cLppContext_ProjOffset);
}

#elif defined(AGL_FRAGMENT_SHADER)
/********************************************************
 *	フラグメントシェーダ
 */

out vec4 oColor;

void main()
{
	LightInfo	light;
	InitLightInfo(light);

	FragInfo	frag;
	
	GBufferInfo g_buf;
	// ベースカラー G-Buffer から情報を抽出
	storeFragInfoByBaseColorGBuffer(frag, g_buf, uBaseColor, getVarying(vTexCoord));
	decodeWorldNrm(g_buf, uNrmMotion, getVarying(vTexCoord));
	
	calcPosV(frag.view_pos
			, uViewLinearDepth
			, getVarying(vScreen)
			, getVarying(vTexCoord)
			, cLppContext_Near
			, cLppContext_Range);

	vec3 pos_to_eye_v = normalize(-frag.view_pos);
	vec3 nrm_v = rotMtx34Vec3(cLppContext_UBO_VMtx, g_buf.normal);
	setNVR(frag, nrm_v, pos_to_eye_v);

	CLAMP_LIGHTBUF(oColor.rgb, calcLineLight(frag, light, uLineLight));
}

#endif // _FRAGMENT_
