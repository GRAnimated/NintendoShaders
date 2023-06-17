/**
 * @file	alVrDistortion.glsl
 * @author	Matsuda Hirokazu  (C)Nintendo
 *
 * @brief	
 */
#include "alVrDistortionUtil.glsl"
 
#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable // 明示的な場所指定には必要。無いと GPU ハング。
#endif

#define	IS_OCULUS_DISTORTION	(0) // @@ id="cIsOculus" choice="0,1" default="0"

layout(binding = 0)
uniform sampler2D uTexture;

//------------------------------------------------------------------------------
// 頂点シェーダ
//------------------------------------------------------------------------------
#if defined(AGL_VERTEX_SHADER)

layout (location=0) in vec4 aPosition;	// @@ id="_p0" hint="position0"
layout (location=1) in vec2 aTexCoord;

out vec2	vTexCoord;
out vec4	vDistortionInfo;

void main()
{
	calcDistortionVs(gl_Position, vTexCoord, vDistortionInfo, aPosition, aTexCoord);

#if defined( AGL_TARGET_GL )

	vTexCoord.y = 1.0 - vTexCoord.y;

#endif
}

//------------------------------------------------------------------------------
// フラグメントシェーダ
//------------------------------------------------------------------------------
#elif defined(AGL_FRAGMENT_SHADER)

in	vec2	vTexCoord;
in	vec4	vDistortionInfo;
out	vec4	oColor;

void main ( void )
{
	oColor  = texture(uTexture, vTexCoord);
	float RI = vDistortionInfo.y;
	applyDistortionVignette(oColor.rgb, RI, vDistortionInfo.z);
}

#endif // AGL_FRAGMENT_SHADER
