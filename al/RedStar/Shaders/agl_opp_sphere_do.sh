/**
 *	@file	agl_opp_sphere_do.sh
 *	@brief	スフィアＤＯ
 *	@author	Matsuda Hirokazu
 */

#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable // 明示的な場所指定には必要。
#endif

#include "agl_lightprepass.shinc"
#include "agl_occlusion_func.shinc"

#define IS_OUTPUT_SHADOW_INTENSITY	(1)
#define IS_OUTPUT_MULT_COLOR		(0)

#define MRT_NUM		(1)

/**
 *	ライトプリパスから取得できるUBO型を流用
 */
layout(std140) uniform Context
{
	LPP_UBO_LAYOUT_CONTEXT
};

/**
 *	スフィアＤＯ
 */
layout(std140) uniform SphereDoView
{
	SphereDo	uSphereDo;
	vec4		uPVWMtx[4];
	vec4		uData; // xyz : color rgb,  w : center_scale
};

#if defined(AGL_VERTEX_SHADER)
/**
 *	頂点シェーダ
 */

layout( location = 0 ) in vec3 aPosition;

noperspective out vec2  vTexCoord;
noperspective out vec3  vScreen;

void main(void)
{
	calcVtxTransform_SpotLight(gl_Position
							, uPVWMtx
							, aPosition
							, uData.w);
	calcScreenCoord(vScreen, vTexCoord, gl_Position, cLppContext_TanFovyHalf, cLppContext_ProjOffset);
}

#elif defined(AGL_FRAGMENT_SHADER)
/**
 *	フラグメントシェーダ
 */

noperspective in vec2  vTexCoord;
noperspective in vec3  vScreen;

BINDING_SAMPLER_TABLE			uniform sampler3D cSphereDoTable;
BINDING_SAMPLER_NORMAL			uniform sampler2D cNormal;
BINDING_SAMPLER_LINEAR_DEPTH	uniform sampler2D cDepth;

//layout(location = 0)	out vec4 oColor;
#if (1 == MRT_NUM)

	#define OutputColor(color)		\
		{							\
			vec4 ret = color;		\
			gl_FragData[0] = ret;			\
		}

#elif (2 == MRT_NUM)

//	layout(location = 1)	out vec4 oColor2;

	#define OutputColor(color)		\
		{							\
			vec4 ret = color;		\
			gl_FragData[0] = ret;			\
			gl_FragData[1] = ret;			\
		}

#endif // MRT_NUM

void main(void)
{
	vec3 view_pos, view_nrm;
	calcPosV(view_pos, cDepth, vScreen, vTexCoord
			, cLppContext_Near, cLppContext_Range);
	calcNrmV(view_nrm, cNormal, vTexCoord);

	float bl;
	calcSphereDo(bl, cSphereDoTable
				   , uSphereDo
				   , view_pos
				   , view_nrm);

#if (IS_OUTPUT_SHADOW_INTENSITY == 1)
	#if (IS_OUTPUT_MULT_COLOR == 1)
		OutputColor(vec4(bl * uData.rgb, bl));
	#else
		OutputColor(vec4(bl));
	#endif // IS_OUTPUT_MULT_COLOR
#else
	#if (IS_OUTPUT_MULT_COLOR == 1)
		OutputColor(vec4(vec3(1.0) - (bl * (vec3(1.0) - uData.rgb)), 1.0 - bl));
	#else
		OutputColor(vec4(1.0 - bl));
	#endif
#endif // IS_OUTPUT_SHADOW_INTENSITY

}

#endif
