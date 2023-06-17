/**
 * @file	alQuaterResBufferLinearDepth.glsl
 * @author	Kitazono Yusuke  (C)Nintendo
 *
 * @brief	パーティクルレンダリング用の縮小線形デプスを作成する
 */

#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable
#endif

uniform sampler2D	uDepth;

#if defined( AGL_VERTEX_SHADER )

in	vec4	aPosition;
in	vec2	aTexCoord1;

out	vec2	vTexCoord;

void main()
{
	gl_Position = vec4(aPosition.xyz, 1.0);
	vTexCoord = aTexCoord1;
}

#endif // defined( AGL_VERTEX_SHADER )

#if defined( AGL_FRAGMENT_SHADER )

in	vec2	vTexCoord;

out	vec4	oColor;

void main()
{
	float d = texture(uDepth, vTexCoord).r;
	oColor = vec4(d);
}

#endif // defined( AGL_FRAGMENT_SHADER )
