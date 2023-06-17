/**
 *	@file	agl_opp_sphere_ao.sh
 *	@brief	Sphere Ambient Occlusion
 *	@author	Matsuda Hirokazu
 */

#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable // 明示的な場所指定には必要。無いと GPU ハング。
#endif

#include "agl_lightprepass.shinc"
#include "agl_occlusion_func.shinc"

#define IS_OUTPUT_SHADOW_INTENSITY	(1)
#define IS_OUTPUT_MULT_COLOR		(0)
/**
 *	ライトプリパスから取得できるUBO型を流用
 */
layout(std140) uniform Context
{
	LPP_UBO_LAYOUT_CONTEXT
};

/**
 *	スフィアＡＯ
 */
layout(std140) uniform SphereAoView
{
	SphereAo	uSphereAo;
	vec4		uPVWMtx[4];
	vec4		uData; // xyz : color rgb
};

#if defined(AGL_VERTEX_SHADER)
/********************************************************
 *	頂点シェーダ
 */

layout(location = 0) in vec3 aPosition;

noperspective out vec2  vTexCoord;
noperspective out vec3  vScreen;

void main(void)
{
	gl_Position = multMtx44Vec3(uPVWMtx, aPosition);
	calcScreenCoord(vScreen, vTexCoord, gl_Position, cLppContext_TanFovyHalf, cLppContext_ProjOffset);
}

#elif defined(AGL_FRAGMENT_SHADER)

/********************************************************
 *	フラグメントシェーダ
 */

noperspective in vec2  vTexCoord;
noperspective in vec3  vScreen;

BINDING_SAMPLER_NORMAL			uniform sampler2D cNormal;
BINDING_SAMPLER_LINEAR_DEPTH	uniform sampler2D cDepth;

out vec4 oColor;

void main(void)
{
	vec3 view_pos, view_nrm;
	calcPosV(view_pos, cDepth, vScreen, vTexCoord
			, cLppContext_Near, cLppContext_Range);
	calcNrmV(view_nrm, cNormal, vTexCoord);

	float ao = calcSphereAo(uSphereAo
						  , view_pos
						  , view_nrm);
	
#if (IS_OUTPUT_SHADOW_INTENSITY == 1)
	#if (IS_OUTPUT_MULT_COLOR == 1)
		oColor = vec4(vec3(1.0) - (ao * (vec3(1.0) - uData.rgb)), 1.0 - ao);
	#else
		oColor = vec4(1.0 - ao);
	#endif
#else
	#if (IS_OUTPUT_MULT_COLOR == 1)
		oColor = vec4(ao * uData.rgb, ao);
	#else
		oColor = vec4(ao);
	#endif
#endif // IS_OUTPUT_SHADOW_INTENSITY
}

#endif