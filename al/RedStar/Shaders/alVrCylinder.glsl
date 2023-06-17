/**
 * @file	alVrCylinder.glsl
 * @author	Hideyuki Sugawara  (C)Nintendo
 *
 * @brief	UIをシリンダー表示するためのシェーダー
 */

#include "alMathUtil.glsl"

layout (binding = 0) uniform uUniformBlock
{
	vec4	cViewProj[4];
};

layout (binding = 0) uniform sampler2D uTexture;

//------------------------------------------------------------------------------
// 頂点シェーダ
//------------------------------------------------------------------------------
#if defined(AGL_VERTEX_SHADER)

layout (location = 0) in vec4 aPosition;
layout (location = 1) in vec2 aTexCoord;

out vec2	vTexCoord;

void main()
{
	gl_Position = multMtx44Vec3(cViewProj, aPosition.xyz);
	vTexCoord = aTexCoord;
}

//------------------------------------------------------------------------------
// フラグメントシェーダ
//------------------------------------------------------------------------------
#elif defined(AGL_FRAGMENT_SHADER)

in	vec2	vTexCoord;
out	vec4	oColor;

void main()
{
	oColor  = texture(uTexture, vTexCoord);
	if (oColor.a == 0.0) discard;
	oColor.rgb /= oColor.a;
}

#endif // AGL_FRAGMENT_SHADER
