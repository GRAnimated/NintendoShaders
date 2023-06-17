/**
 * @file	alQuaterResBufferCompose.glsl
 * @author	Kitazono Yusuke  (C)Nintendo
 *
 * @brief	パーティクルレンダリング用の縮小バッファを合成する
 */

#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable
#endif

uniform sampler2D	uColorTex;
uniform float		uLimitVariance;
uniform float		uPMaxMul;

#if IS_VDM == 1
uniform sampler2D	uVdmTex;
uniform sampler2D	uLinearDepthTex;
#endif // IS_VDM == 1

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
#if IS_VDM == 1

#else
	oColor = texture(uColorTex, vTexCoord);
#endif // IS_VDM == 1
}

#endif // defined( AGL_FRAGMENT_SHADER )
