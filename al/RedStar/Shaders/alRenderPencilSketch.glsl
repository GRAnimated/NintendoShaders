/**
 * @file	alRenderPencilSketch.glsl
 * @author	Musa Kazuhiro  (C)Nintendo
 *
 * @brief	えんぴつ画描画
 */
#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable // 明示的な場所指定には必要。無いと GPU ハング。
#endif

#define IS_USE_CANVAS_TEX		(0) // @@ id="cIsUseCanvasTex" 		choice="bool"		default="0"
#define IS_USE_NOISE_TEX		(0) // @@ id="cIsUseNoiseTex" 		choice="bool"		default="0"
#define IS_USE_INDIRECT1_TEX	(0) // @@ id="cIsUseIndirect1Tex" 	choice="bool"		default="0"
#define IS_USE_INDIRECT2_TEX	(0) // @@ id="cIsUseIndirect2Tex" 	choice="bool"		default="0"

#include "alDeclareUniformBlockBinding.glsl"
#include "alDeclareMdlEnvView.glsl"
#include "alMathUtil.glsl"
#include "alScreenUtil.glsl"

layout(binding = 0) uniform sampler2D uFrameBuffer;
layout(binding = 1) uniform sampler2D uLinearDepthTex;
//layout(binding = 2) uniform sampler3D uNoiseTexture;
//layout(binding = 3) uniform sampler2D uIndirectTexture1;
//layout(binding = 4) uniform sampler2D uIndirectTexture2;

uniform vec4	uParams;	//x: toon_rate yzw: toon_step 
uniform vec4	uParams2;	//xyz: toon_width w: noise_mix_rate
uniform vec4	uParams3;	//xyz: noise_add w: noise_scale
uniform vec4	uParams4;	//x: canvas_mix y: canvas_repeat
uniform vec4	uIndirectScale;		//x: indirect1_scale y: indirect2_scale
uniform vec4	uIndirectTexOffset;	//xy: indirect1_tex_offset zw: indirect2_tex_offset
uniform vec4	uIndirectTexScale;	//xy: indirect1_tex_scale zw: indirect2_tex_scale

//------------------------------------------------------------------------------
// 頂点シェーダ
//------------------------------------------------------------------------------
#if defined(AGL_VERTEX_SHADER)

layout (location = 0) in vec3 aPosition;	// @@ id="_p0" hint="position0"
layout (location = 1) in vec2 aTexCoord1;
out vec2 vTexCoord;
out vec2 vInd1Coord;
out vec2 vInd2Coord;
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
#if IS_USE_INDIRECT1_TEX
	vInd1Coord = vTexCoord * uIndirectTexScale.xy + uIndirectTexOffset.xy;
#endif
#if IS_USE_INDIRECT2_TEX
	vInd2Coord = vTexCoord * uIndirectTexScale.zw + uIndirectTexOffset.zw;
#endif
}

//------------------------------------------------------------------------------
// フラグメントシェーダ
//------------------------------------------------------------------------------
#elif defined(AGL_FRAGMENT_SHADER)

in vec2	vTexCoord;
in vec2 vInd1Coord;
in vec2 vInd2Coord;
in vec2	vScreen;
// 出力変数
layout(location = 0)	out vec4 oColor;

void main()
{
	vec2 tex_coord = vTexCoord;
	float dv = 1.0/720;		// @todo ubo経由で渡す
	float dh = 1.0/1280;

	vec2 dir  = vec2(0.6,0.4);
	vec2 unit = vec2(dh,dv);
	unit = dir*unit;

	vec3 color	= vec3(0.0);
	vec2 v		= vec2(0.0);

	float depth	= texture( uLinearDepthTex, vTexCoord ).r;
	int blur_len = int(5+20.0*clamp01(depth)*0.5);

	for( int i=0; i<blur_len; ++i )
	{
		vec2 tex_coord_ref = tex_coord + v;

		float seed = 128.0;
		float rand = fract( sin( dot( tex_coord_ref, vec2( 12.9898, 78.233 ) ) + seed ) * 43758.5453 );
		vec3 color_ref = texture( uFrameBuffer, tex_coord_ref ).rgb;

		float intensity = color_ref.r * 0.298912 + color_ref.g * 0.586611 + color_ref.b * 0.114478;

		//color +=  texture( uFrameBuffer, tex_coord_ref ).rgb * step( rand, intensity*3.0);
		color += vec4( 1.0 ).rgb* step( rand, intensity*3.0);
		v += unit;
	}

	color /= blur_len;
	oColor = vec4( color, 1.0 );
}
#endif // defined(AGL_FRAGMENT_SHADER)

