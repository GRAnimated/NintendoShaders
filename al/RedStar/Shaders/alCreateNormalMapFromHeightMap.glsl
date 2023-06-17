/**
 * @file	alCreateNormalMapFromHeightMap.glsl
 * @author	Yosuke Mori  (C)Nintendo
 *
 * @brief	ハイトマップからノーマルマップを作成
 */

#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable // 明示的な場所指定には必要。無いと GPU ハング。
#endif

#include "alMathUtil.glsl"

// ModelEnv とかぶらないように。
layout(std140, binding = 2) uniform CreateNormalMapFromHightMap
{
	float	uInvWidth;
	float	uInvHeight;
	float	uInvInterval;
};

#if defined( AGL_VERTEX_SHADER )

in vec3 aPosition;
out vec2 vSignPos;

void main( void )
{
	vec2 sign_pos = sign(aPosition.xy); // 画面を覆う -1 〜 1 の範囲のスクリーン座標になる
	gl_Position.xy = sign_pos;
	gl_Position.z = 1.0;
	gl_Position.w = 1.0;

	vSignPos = sign_pos * 0.5 + 0.5;
}

#elif defined( AGL_FRAGMENT_SHADER )

layout(location = 0) out vec4 oColor;

layout(binding = 1)
uniform sampler2D	cTextureHeightMap;

in vec2 vSignPos;

void main()
{
	vec2 tex_coord  = vec2(vSignPos.x, 1.0 - vSignPos.y);
	vec2 tex_coord0 = vec2(tex_coord.x, tex_coord.y - uInvHeight);
	vec2 tex_coord1 = vec2(tex_coord.x - uInvWidth, tex_coord.y);
	vec2 tex_coord2 = vec2(tex_coord.x + uInvWidth, tex_coord.y);
	vec2 tex_coord3 = vec2(tex_coord.x, tex_coord.y + uInvHeight);

	float h0 = texture(cTextureHeightMap, tex_coord0).r;
	float h1 = texture(cTextureHeightMap, tex_coord1).r;
	float h2 = texture(cTextureHeightMap, tex_coord2).r;
	float h3 = texture(cTextureHeightMap, tex_coord3).r;

	vec3 normal;
	normal.x = h1 - h2;
	normal.y = 2.0 * uInvInterval;
	normal.z = h0 - h3;
	normal = normalize(normal);

	oColor.r = normal.x;
	oColor.g = normal.z;
}

#endif
