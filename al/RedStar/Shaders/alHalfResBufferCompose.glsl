/**
 * @file	alReducedBufferAdjustUtil.glsl
 * @author	Matsuda Hirokazu  (C)Nintendo
 *
 * @brief	縮小バッファのぴったりくん Util
 */
#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable
#endif

#include "alMathUtil.glsl"
#include "alCalcFullScreenTriangle.glsl"
#include "alReducedBufferAdjustUtil.glsl"

#define IS_ADJUST	(0)

uniform float uNear;
uniform float uInvRange;

#define BINDING_SAMPLER_DEPTH				layout(binding = 9)
#define BINDING_SAMPLER_HALF_DEPTH			layout(binding = 10)
#define BINDING_SAMPLER_COLOR				layout(binding = 11)
BINDING_SAMPLER_DEPTH				uniform sampler2D cViewDepth;
BINDING_SAMPLER_HALF_DEPTH			uniform sampler2D cHalfViewDepth;
BINDING_SAMPLER_COLOR				uniform sampler2D cReduceBuf;

//------------------------------------------------------------------------------
// 頂点シェーダ
//------------------------------------------------------------------------------
#if defined(AGL_VERTEX_SHADER)

layout (location=0) in vec4 aPosition;	// @@ id="_p0" hint="position0"
out	vec2	vTexCoord;

void main()
{
	// 全画面を覆う三角形
	CalcFullScreenTriPosUv(gl_Position, aPosition, vTexCoord);

	#if (IS_ADJUST == 1)
	// ぴったりくん準備
	calcTexCoordReducedBufferAdjust(vTexCoord);
	#endif
}

//------------------------------------------------------------------------------
// フラグメントシェーダ
//------------------------------------------------------------------------------
#elif defined(AGL_FRAGMENT_SHADER)

in	vec2	vTexCoord;
// 出力変数
layout(location = 0)	out vec4 oColor;

void main()
{
	vec2 uv = vTexCoord;

	#if (IS_ADJUST == 1)
	float full_depth = texture(cViewDepth, vTexCoord).r;
	calcReducedBufferAdjustUV(uv, full_depth, cHalfViewDepth, vTexCoord, uNear, uInvRange);
	#endif // IS_ADJUST

	oColor = texture(cReduceBuf, uv);
}

#endif // AGL_FRAGMENT_SHADER
