/**
 * @file	alRenderCartoon.glsl
 * @author	Yosuke Mori  (C)Nintendo
 *
 * @brief	トゥーン描画
 */
#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable // 明示的な場所指定には必要。無いと GPU ハング。
#endif

#define IS_USE_CANVAS_TEX		(0) // @@ id="cIsUseCanvasTex" 		choice="bool"		default="0"
#define IS_USE_NOISE_TEX		(0) // @@ id="cIsUseNoiseTex" 		choice="bool"		default="0"
#define IS_USE_INDIRECT_TEX		(0) // @@ id="cIsUseIndirect1Tex" 	choice="bool"		default="0"
#define IS_USE_FISH_EYE			(0) // @@ id="cIsUseFishEye" 		choice="bool"		default="0"

#include "alDeclareUniformBlockBinding.glsl"
#include "alDeclareMdlEnvView.glsl"
#include "alMathUtil.glsl"
#include "alScreenUtil.glsl"

layout(binding = 0) uniform sampler2D uFrameBuffer;
layout(binding = 1) uniform sampler2D uLinearDepthTex;
layout(binding = 2) uniform sampler3D uNoiseTexture;
layout(binding = 3) uniform sampler3D uCanvasTexture;
layout(binding = 4) uniform sampler2D uIndirectTexture;

uniform vec4	uParams;			//x: toon_rate yzw: toon_step 
uniform vec4	uParams2;			//xyz: toon_width w: noise_mix_rate
uniform vec4	uNoiseParam;		//xyz: noise_add w: noise_scale
uniform vec4	uCanvasParam;		//x: canvas_mix y: canvas_repeat
uniform vec4	uIndirectTexParam1;	//xy: indirect_tex_offset zw: indirect_tex_scale
uniform vec4	uIndirectTexParam2;	//x:  indirect_scale
uniform vec4	uFishEyeParam;		//x:  fish_eye_param y: aspect

//------------------------------------------------------------------------------
// 頂点シェーダ
//------------------------------------------------------------------------------
#if defined(AGL_VERTEX_SHADER)

layout (location = 0) in vec3 aPosition;	// @@ id="_p0" hint="position0"
layout (location = 1) in vec2 aTexCoord1;
out vec2 vTexCoord;
out vec2 vIndCoord;
out	vec2 vScreen;

void main()
{
	VERTEX_SHADER_QUAD_TRIANGLE__CALC_POS_TEX

	vScreen.xy = gl_Position.xy / gl_Position.w;
#if defined( AGL_TARGET_GX2 ) || defined( AGL_TARGET_NVN )
	vScreen.y *= -1.0;
#endif
	vScreen.xy *= -cTanFovyHalf.xy;
	vScreen.xy -= cScrProjOffset.xy;
#if IS_USE_INDIRECT_TEX
	vIndCoord = vTexCoord * uIndirectTexParam1.zw + uIndirectTexParam1.xy;
#endif
}

//------------------------------------------------------------------------------
// フラグメントシェーダ
//------------------------------------------------------------------------------
#elif defined(AGL_FRAGMENT_SHADER)

in vec2	vTexCoord;
in vec2 vIndCoord;
in vec2	vScreen;
// 出力変数
layout(location = 0)	out vec4 oColor;

void main()
{
	vec2 tex_coord = vTexCoord;
	vec2 ind = vec2(0.0);
	#if IS_USE_INDIRECT_TEX
	{
		ind = texture( uIndirectTexture, vIndCoord ).rg - vec2( 0.5, 0.5 );
		ind.x *= uIndirectTexParam2.x;
		ind.y *= -uIndirectTexParam2.x;
		tex_coord += ind;
	}
	#endif

	#if IS_USE_FISH_EYE
	{
		tex_coord = tex_coord * 2.0 - 1.0;
		vec2 length_coord = tex_coord;
		length_coord.x *= uFishEyeParam.y;
		float length = length( length_coord );
		tex_coord = ( 1.0 + uFishEyeParam.x * length * length ) / ( 1.0 + 2.0 * uFishEyeParam.x ) * tex_coord;
		tex_coord = tex_coord * 0.5 + 0.5;
	}
	#endif

	vec3 color	= texture( uFrameBuffer, tex_coord ).rgb;
	float lumi	= color.r * 0.298912 + color.g * 0.586611 + color.b * 0.114478;
	vec3 dark	= color * color * color * color;
	vec3 rate3	= smoothstep( uParams.yzw, uParams.yzw + uParams2.xyz, vec3( lumi ) );
	float rate	= ( rate3.x + rate3.y + rate3.z ) * 0.33333;
	color = mix( dark, color, max( clamp01( rate ), clamp01( 1.0 - uParams.x ) ) );

	float noise = 0.0;
	float noise_canvas = 0.0;
	#if IS_USE_NOISE_TEX
	{
		float depth	= texture( uLinearDepthTex, vTexCoord ).r;
		vec3 view_pos;
		view_pos.z = -( depth * cRange + cNear );
		view_pos.xy = vScreen * view_pos.z;
		vec3 pos_w = multMtx34Vec3( cInvView, view_pos );
		noise = clamp01(texture( uNoiseTexture, pos_w * uNoiseParam.w + uNoiseParam.xyz ).r);
	}
	#endif

	#if IS_USE_CANVAS_TEX
	{
		vec3 canvas_coord = vec3( vTexCoord * uCanvasParam.y, 1.0 );
		noise_canvas = clamp01(texture( uCanvasTexture, canvas_coord ).r);
	}
	#endif

	#if IS_USE_NOISE_TEX || IS_USE_CANVAS_TEX
	{
		float min_rgb = min( color.r, min( color.g, color.b ) );
		float max_rgb = max( color.r, max( color.g, color.b ) );
		float sat = 1.0 - min_rgb / ( max_rgb + 1.0e-10 );
		float new_sat = clamp01( sat + noise * uNoiseParam.w - noise_canvas * uCanvasParam.x );
		float sat_scale = clamp( new_sat / sat, 0.5, 2.0 );
		color = color - vec3( min_rgb );
		color = color * sat_scale + vec3( max_rgb - ( max_rgb - min_rgb ) * sat_scale );
	}
	#endif

	oColor = vec4( clamp01( color ), 1.0 );
}
#endif // defined(AGL_FRAGMENT_SHADER)

