/**
 * @file	alHalfResBuffer.glsl
 * @author	Yosuke Mori  (C)Nintendo
 *
 * @brief	1/2 * 1/2の縮小バッファを作成
 */

#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable
#endif

#include "alScreenUtil.glsl"
#include "alDefineVarying.glsl"

#define BINDING_SAMPLER_SRC_TEX		layout(binding = 0)

BINDING_SAMPLER_SRC_TEX uniform sampler2D	uSrcTex;

uniform vec2		uTexelSize;

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
	vec4 color;
	oColor = texture(uSrcTex, vTexCoord);
}

#endif // defined( AGL_FRAGMENT_SHADER )
