/**
 * @file	alHeightMapToInit.glsl
 * @author	Yosuke Mori  (C)Nintendo
 *
 * @brief	ハイトマップを初期状態に近づける
 */

#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable // 明示的な場所指定には必要。無いと GPU ハング。
#endif

#include "alMathUtil.glsl"

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
uniform sampler2D	cTextureInitHeightMap;

in vec2 vSignPos;

void main()
{
	oColor.r = texture(cTextureInitHeightMap, vSignPos).r;
}

#endif
