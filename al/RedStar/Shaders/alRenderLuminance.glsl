/**
 * @file	alRenderLuminance.glsl
 * @author	Yosuke Mori  (C)Nintendo
 *
 * @brief	輝度のデバッグ描画
 */
#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable // 明示的な場所指定には必要。無いと GPU ハング。
#endif

#include "alMathUtil.glsl"
#include "alScreenUtil.glsl"

layout(binding = 0) uniform sampler2D uFrameBuffer;

//------------------------------------------------------------------------------
// 頂点シェーダ
//------------------------------------------------------------------------------
#if defined(AGL_VERTEX_SHADER)

layout (location = 0) in vec3 aPosition;	// @@ id="_p0" hint="position0"
layout (location = 1) in vec2 aTexCoord1;
out vec2 vTexCoord;

void main()
{
	VERTEX_SHADER_QUAD_TRIANGLE__CALC_POS_TEX
}

//------------------------------------------------------------------------------
// フラグメントシェーダ
//------------------------------------------------------------------------------
#elif defined(AGL_FRAGMENT_SHADER)

in	vec2	vTexCoord;
out	vec4	oColor;

void main()
{
	vec3 color = texture(uFrameBuffer, vTexCoord).rgb;
	float luminance = color.r * 0.298912 + color.g * 0.586611 + color.b * 0.114478;

	oColor = vec4(luminance, luminance, luminance, 1.0);
}
#endif // defined(AGL_FRAGMENT_SHADER)

