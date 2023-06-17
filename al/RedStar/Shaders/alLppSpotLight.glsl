/**
 * @file	alLppSpotLight.glsl
 * @author	Yosuke Mori  (C)Nintendo
 *
 * @brief	ライトプリパスのスポットライト
 */
 
#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable // 明示的な場所指定には必要。無いと GPU ハング。
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
 *	スポットライト
 */
layout(std140) uniform SpotLightView
{
	SpotLight	uSpotLight;
	vec4		uPVWMtx[4];
	float		uCenterScale;
};

#if defined(AGL_VERTEX_SHADER)
/**
 *	頂点シェーダ
 */

layout( location = 0 ) in vec3 aPosition;

void main(void)
{
	calcVtxTransform_SpotLight(gl_Position
							, uPVWMtx
							, aPosition
							, uCenterScale);
	calcScreenCoord(vScreen, vTexCoord, gl_Position, cLppContext_TanFovyHalf, cLppContext_ProjOffset);
}

#elif defined(AGL_FRAGMENT_SHADER)
/**
 *	フラグメントシェーダ
 */

out vec4 oColor;

void main()
{
	#if (IS_DEBUG_DRAW == 1)
	{
		oColor = uColor;
	//	vec3 nrm = texture2D(uNrmMotion, getVarying(vTexCoord)).rgb;
	//	oColor.rgb = mix(nrm, texture2D(uBaseColor, getVarying(vTexCoord)).rgb, uColor.a);
		oColor.rgb = texture2D(uBaseColor, getVarying(vTexCoord)).aaa; // ラフネスとメタルネスとZ符号
	}
	#else
	{
		LightInfo	light;
		InitLightInfo(light);
		
		FragInfo	frag;
		calcPosV(frag.view_pos
				, uViewLinearDepth
				, getVarying(vScreen)
				, getVarying(vTexCoord)
				, cLppContext_Near
				, cLppContext_Range);
		
		GBufferInfo g_buf;
		// ベースカラー G-Buffer から情報を抽出
		storeFragInfoByBaseColorGBuffer(frag, g_buf, uBaseColor, getVarying(vTexCoord));
		decodeWorldNrm(g_buf, uNrmMotion, getVarying(vTexCoord));

		vec3 pos_to_eye_v = normalize(-frag.view_pos);
		vec3 nrm_v = rotMtx34Vec3(cLppContext_UBO_VMtx, g_buf.normal);
		setNVR(frag, nrm_v, pos_to_eye_v);

		CLAMP_LIGHTBUF(oColor.rgb,calcSpotLight(frag, light, uSpotLight));
	}
	#endif // (IS_DEBUG_DRAW == 1)
}

#endif // _FRAGMENT_

