/**
 * @file	alTransformHeightMap.glsl
 * @author	Yosuke Mori  (C)Nintendo
 *
 * @brief	ハイトマップを変形
 */

#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable // 明示的な場所指定には必要。無いと GPU ハング。
#endif

#include "alMathUtil.glsl"

// ModelEnv とかぶらないように。
layout(std140, binding = 2) uniform TransformHeightMap
{
	float	uPushAreaRate;
	float	uInvPushAreaLength;
	float	uPushDepth;
};

#if defined( AGL_VERTEX_SHADER )

layout(binding = 9)
uniform sampler1D	cTextureTouchInfo;

in vec3 aPosition;
out vec2 vSignPos;
out vec2 vPushPos;
out float vTouchFlag;

void main( void )
{
	vec2 push_pos = texture(cTextureTouchInfo, 0.0).rg;
	vec2 pos      = aPosition.xy * uPushAreaRate;
	pos.x = pos.x - (0.5 - push_pos.x) * 2.0;
	pos.y = pos.y - (0.5 - push_pos.y) * 2.0;

	gl_Position.xy = pos;
	gl_Position.z = 1.0;
	gl_Position.w = 1.0;

	vSignPos   = pos;
	vPushPos   = push_pos * 2.0 - 1.0;
	if( push_pos.x < 0.0 || push_pos.y < 0.0 )
	{
		vTouchFlag = 0.0;
	}
	else
	{
		vTouchFlag = 1.0;
	}
}

#elif defined( AGL_FRAGMENT_SHADER )

layout(location = 0) out vec4 oColor;

layout(binding = 8)
uniform sampler1D	cTexTransformHeightMap;

in vec2 vSignPos;
in vec2 vPushPos;
in float vTouchFlag;

void main()
{
	vec2 dist = vSignPos - vec2(vPushPos);
	float coord = clamp01(length(dist) * uInvPushAreaLength);
	oColor.r = texture(cTexTransformHeightMap, coord).r * uPushDepth * vTouchFlag;
}

#endif
