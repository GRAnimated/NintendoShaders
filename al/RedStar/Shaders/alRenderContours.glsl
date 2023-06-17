/**
 * @file	alRenderColorClamp.glsl
 * @author	Satoshi Miyama  (C)Nintendo
 *
 * @brief	輪郭線描画
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

#define KERNEL_SIZE			(0) // @@ id="cKernelSize" choice = "0,1,2" default = "0"
#define KERNEL_SIZE_0		(0)
#define KERNEL_SIZE_1		(1)
#define KERNEL_SIZE_2		(2)

#define IS_NEON				(0) // @@ id="cIsNeon" choice = "0,1" default = "0"
#define IS_USE_DEPTH		(0) // @@ id="cIsUseDepth" choice = "0,1" default = "0"

uniform float	uThreshold;
uniform float	uThresholdDepth;
uniform float	uBrightnessOffset;
uniform vec2	uTexcel;

layout( binding = 0 ) uniform sampler2D uOrgColor;
layout( binding = 1 ) uniform sampler2D uOrgDepth;

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

vec3 rgb2hsv(vec3 c)
{
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));

	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c)
{
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

vec3 maxcolor4_rgb(sampler2D sampler, vec2 center, vec2 v0, vec2 v1, vec2 v2, vec2 v3)
{
	return max(	max( texture( sampler, center+v0 ).rgb, texture( sampler, center+v1 ).rgb),
				max( texture( sampler, center+v2 ).rgb, texture( sampler, center+v3 ).rgb) );
}

float maxcolor4_r(sampler2D sampler, vec2 center, vec2 v0, vec2 v1, vec2 v2, vec2 v3)
{
	return max(	max( texture( sampler, center+v0 ).r,   texture( sampler, center+v1 ).r),
				max( texture( sampler, center+v2 ).r,   texture( sampler, center+v3 ).r) );
}

void main()
{
	vec2 sc = getScreenCoord();
	float w = uTexcel.x;
	float h = uTexcel.y;

	vec3 org_color	=               texture( uOrgColor, sc ).rgb;
	vec3 neighbor	=               maxcolor4_rgb( uOrgColor, sc, vec2( 0, h), vec2( w, 0), vec2( 0,-h), vec2(-w, 0));
#if ( KERNEL_SIZE == KERNEL_SIZE_1 || KERNEL_SIZE == KERNEL_SIZE_2 )
	neighbor		= max(neighbor, maxcolor4_rgb( uOrgColor, sc, vec2( w, h), vec2( w,-h), vec2(-w,-h), vec2(-w, h)));
  #if ( KERNEL_SIZE == KERNEL_SIZE_2 )
	w *= 2.0; h *= 2.0;
	neighbor		= max(neighbor, maxcolor4_rgb( uOrgColor, sc, vec2( 0, h), vec2( w, 0), vec2( 0,-h), vec2(-w, 0)));
  #endif	// KERNEL_SIZE_2
#endif	// KERNEL_SIZE_1 || KERNEL_SIZE_2

#if IS_USE_DEPTH
	w = uTexcel.x;
	h = uTexcel.y;

	float org_depth	=                texture( uOrgDepth, sc ).r;
	float neighbor_d =                maxcolor4_r( uOrgDepth, sc, vec2( 0, h), vec2( w, 0), vec2( 0,-h), vec2(-w, 0));
#if ( KERNEL_SIZE == KERNEL_SIZE_1 || KERNEL_SIZE == KERNEL_SIZE_2 )
	neighbor_d		= max(neighbor_d, maxcolor4_r( uOrgDepth, sc, vec2( w, h), vec2( w,-h), vec2(-w,-h), vec2(-w, h)));
  #if ( KERNEL_SIZE == KERNEL_SIZE_2 )
	w *= 2.0; h *= 2.0;
	neighbor_d		= max(neighbor_d, maxcolor4_r( uOrgDepth, sc, vec2( 0, h), vec2( w, 0), vec2( 0,-h), vec2(-w, 0)));
  #endif	// KERNEL_SIZE_2
#endif	// KERNEL_SIZE_1 || KERNEL_SIZE_2
	float diff_depth = abs(neighbor_d - org_depth);
#endif	// IS_USE_DEPTH

	vec3 diff_rgb	= abs(neighbor - org_color);
	float diff		= max(diff_rgb.r, max(diff_rgb.g, diff_rgb.b));

	float is_edge	= step(uThreshold, diff);

#if IS_USE_DEPTH
	is_edge			+= step(uThresholdDepth, diff_depth);
#endif

#if IS_NEON
	if(is_edge!=0)
	{
		oColor.rgb		= org_color;
		vec3 hsv = rgb2hsv( oColor.rgb );
		hsv.z = hsv.z * (1-uBrightnessOffset) + uBrightnessOffset;
		oColor.rgb = hsv2rgb(hsv);
	}else{
		oColor.rgb		= vec3(0);
	}
#else
	if(is_edge!=0){
		oColor.rgb		= vec3(0);
	}else{
		oColor.rgb		= org_color;
	}
#endif
	oColor.a = 1.0;
}
#endif // defined( AGL_FRAGMENT_SHADER )

