/**
 * @file	alRenderViewDepth.glsl
 * @author	Yosuke Mori  (C)Nintendo
 *
 * @brief	デプス描画
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

uniform vec4	uParams; //x: near y: far z: range w: inv_range
uniform vec4	uFarColor; //xyzw: far color
uniform vec4	uNearColor; //xyzw: near color
uniform vec4	uOffsetColor; //xyzw: offset color

layout( binding = 0 ) uniform sampler2D uDepth;
DECLARE_VARYING( vec3,	vParameters );

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
	
	getVarying( vParameters )	= vec3( -uParams.y * uParams.w, uParams.z / uParams.x, uParams.x * uParams.w );
}

//------------------------------------------------------------------------------
// フラグメントシェーダ
//------------------------------------------------------------------------------
#elif defined( AGL_FRAGMENT_SHADER )

// 出力変数
layout( location = 0 )	out vec4 oColor;

void main()
{
	float depth	= texture( uDepth, getScreenCoord() ).r;

	float a = getVarying( vParameters ).x;
	float b = getVarying( vParameters ).y;
	float linear_depth = 0.0;
	linear_depth = a / ( ( depth + a ) * b );
	linear_depth = linear_depth - getVarying( vParameters ).z;
	vec3 color = mix( uNearColor.rgb, uFarColor.rgb, linear_depth );
	float base_r = color.r;
	color.r = pow( base_r, 1.0 / ( uOffsetColor.r * uOffsetColor.a ) );
	color.g = pow( base_r, 1.0 / ( uOffsetColor.g * uOffsetColor.a ) );
	color.b = pow( base_r, 1.0 / ( uOffsetColor.b * uOffsetColor.a ) );
	color = clamp01( color );
	oColor = vec4( color, 1.0 );
}
#endif // defined( AGL_FRAGMENT_SHADER )

