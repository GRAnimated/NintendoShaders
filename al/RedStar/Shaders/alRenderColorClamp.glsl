/**
 * @file	alRenderColorClamp.glsl
 * @author	Yosuke Mori  (C)Nintendo
 *
 * @brief	カラーのクランプ
 */
#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable // 明示的な場所指定には必要。無いと GPU ハング。
#endif

#include "alMathUtil.glsl"
#include "alScreenUtil.glsl"
#include "alDeclareUniformBlockBinding.glsl"

#define USING_SCREEN_AND_TEX_COORD_CALC	(1)
#include "alDefineVarying.glsl"
#include "alDeclareMdlEnvView.glsl"

uniform vec4	uParams; //x: clamp r, y: clamp g z: clamp g

layout( binding = 0 ) uniform sampler2D uOrgColor;

//------------------------------------------------------------------------------
// 頂点シェーダ
//------------------------------------------------------------------------------
#if defined( AGL_VERTEX_SHADER )

layout (location = 0) in vec3 aPosition;	// @@ id="_p0" hint="position0"

void main()
{
	gl_Position.xy = 2.0 * aPosition.xy;
	gl_Position.z  = 0.0;
	gl_Position.w  = 1.0;
	calcScreenAndTexCoord();
}

//------------------------------------------------------------------------------
// フラグメントシェーダ
//------------------------------------------------------------------------------
#elif defined( AGL_FRAGMENT_SHADER )

// 出力変数
layout( location = 0 )	out vec4 oColor;

void main()
{
	vec3 org_color	= texture( uOrgColor, getScreenCoord() ).rgb;
	oColor.r = clamp( org_color.r, 0.0, uParams.x );
	oColor.g = clamp( org_color.g, 0.0, uParams.y );
	oColor.b = clamp( org_color.b, 0.0, uParams.z );
	oColor.a = 1.0;
}
#endif // defined( AGL_FRAGMENT_SHADER )

