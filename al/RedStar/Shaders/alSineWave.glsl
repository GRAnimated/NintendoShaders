/**
 * @file	alSineWave.glsl
 * @author	Tatsuya Kurihara  (C)Nintendo
 *
 * @brief	サイン波を描く
 */
#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable // 明示的な場所指定には必要。無いと GPU ハング。
#endif
precision highp float;

#include "alMathUtil.glsl"
#include "alDeclareUniformBlockBinding.glsl"

//------------------------------------------------------------------------------
// 頂点シェーダ
//------------------------------------------------------------------------------
#if defined(AGL_VERTEX_SHADER)

layout (location = 0) in vec3 aPosition;	// @@ id="_p0" hint="position0"
layout (location = 1) in vec2 aTexCoord;
out vec2 vTexCrd;

void main()
{
	gl_Position.xy = 2.0 * aPosition.xy;
	gl_Position.z  = 0.0;
	gl_Position.w  = 1.0;

	vTexCrd = aTexCoord;
#if defined( AGL_TARGET_GL )
	vTexCrd.y = 1.0 - vTexCrd.y;
#endif
}

//------------------------------------------------------------------------------
// フラグメントシェーダ
//------------------------------------------------------------------------------
#elif defined(AGL_FRAGMENT_SHADER)

BINDING_UBO_OTHER_FIRST uniform SineWave 
{
	vec4 uData;
	vec4 uData2;
};

#define WAVE_HEIGHT	uData.x
#define WAVE_WIDTH  uData.y
#define WAVE_CYCLE  uData.z
#define WAVE_ANGLE  uData.w
#define TIME		uData2.x

in  vec2	vTexCrd;
out	vec4	oColor;

void main()
{
	vec2 dir = vec2(cos(WAVE_ANGLE), sin(WAVE_ANGLE));

	float angle_deg = 360.0 * dot(dir, vTexCrd) / WAVE_WIDTH + TIME / WAVE_CYCLE;
	float angle_rad = angle_deg * PI / 180.0;
	float height = sin(angle_rad) * WAVE_HEIGHT;

	float angle_rad_small =  (360.0 * dot(dir, vTexCrd) * 2.5 / WAVE_WIDTH + TIME * 2 / WAVE_CYCLE ) * PI / 180.0;
	float height_small = sin(angle_rad_small) * WAVE_HEIGHT * 0.1;

	vec2 dir_vertical = vec2(cos(WAVE_ANGLE + PI/2), sin(WAVE_ANGLE + PI/2));
	float angle_rad_vertical = (360.0 * dot(dir_vertical, vTexCrd) / WAVE_WIDTH + TIME * 3 / WAVE_CYCLE ) * PI / 180.0;
	float height_vertical = sin(angle_rad_vertical) * WAVE_HEIGHT * 0.1;

	oColor = vec4(height + height_small + height_vertical, 0.0,  0.0, 1.0);
}
#endif // defined(AGL_FRAGMENT_SHADER)
