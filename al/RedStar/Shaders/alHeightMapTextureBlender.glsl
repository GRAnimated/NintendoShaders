/**
 * @file	alHeightMapTextureBlender.glsl
 * @author	Tatsuya Kurihara  (C)Nintendo
 *
 * @brief	HeightMap合成
 */
#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable // 明示的な場所指定には必要。無いと GPU ハング。
#endif

precision highp float;

#include "alDeclareUniformBlockBinding.glsl"

uniform sampler2D uTex0;
uniform sampler2D uTex1;
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
in	vec2	vTexCrd;
out	vec4	oColor;

void main()
{
	vec4 c0 = texture(uTex0, vTexCrd);
	vec4 c1 = texture(uTex1, vTexCrd);

	oColor = vec4(c1.r + c0.r, 0.0, c0.r, 1.0);
}
#endif // defined(AGL_FRAGMENT_SHADER)
