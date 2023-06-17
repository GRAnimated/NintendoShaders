/**
 * @file	alComposeMask.glsl
 * @author	Yosuke Mori  (C)Nintendo
 *
 * @brief	マスクテクスチャとの画像合成
 */

#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable
#endif

#include "alScreenUtil.glsl"
#include "alDefineVarying.glsl"

#define BINDING_SAMPLER_SRC_TEX		layout(binding = 0)
#define BINDING_SAMPLER_MASK_TEX	layout(binding = 1)

BINDING_SAMPLER_SRC_TEX uniform sampler2D	uSrcTex;
BINDING_SAMPLER_MASK_TEX uniform sampler2D	uMaskTex;

#if defined( AGL_VERTEX_SHADER )

layout ( location = 0 )	in	vec4	aPosition;
layout ( location = 1 )	in	vec2	aTexCoord1;

out	vec2	vTexCoord;

void main()
{
	VERTEX_SHADER_QUAD_TRIANGLE__CALC_POS_TEX
}

#endif // defined( AGL_VERTEX_SHADER )

#if defined( AGL_FRAGMENT_SHADER )

in	vec2	vTexCoord;
layout(location = 0)	out vec4	oColor;

void main()
{
	vec4 src_color;
	vec4 mask_color;
	src_color = texture(uSrcTex, vTexCoord);
	mask_color = texture(uMaskTex, vTexCoord);
	oColor = src_color * sign(mask_color.rrrr);
}

#endif // defined( AGL_FRAGMENT_SHADER )
