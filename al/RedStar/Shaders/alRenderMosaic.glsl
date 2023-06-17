/**
 * @file	alRenderMosaic.glsl
 * @author	Yosuke Mori  (C)Nintendo
 *
 * @brief	モザイク画
 */


#include "alDeclareUniformBlockBinding.glsl"
#include "alDefineVarying.glsl"
#include "alDeclareMdlEnvView.glsl"
#include "alMathUtil.glsl"
#include "alGBufferUtil.glsl"
#include "alLightingFunction.glsl"
#include "alScreenUtil.glsl"
#include "alCalcNormal.glsl"
#include "alCalcLighting.glsl"

#define PASS (0) // @@ id="cPass" 					choice="bool"		default="0"

uniform vec4 uParams1; //xyz: light_color  : w: tile_num_x
uniform vec4 uParams2; //xyz: light_color2 : w: tile_num_y
uniform vec4 uParams3; //xyz: light_dir    : w: exposure
uniform vec4 uParams4; //xyz: light_dir2   : w: noise_mix_rate
uniform vec4 uParams5; //xyz: tile_groove_color
uniform	float uCrossOver;
uniform	vec4 uToeCoeff;
uniform	vec4 uSholuderCoeff;

layout( binding = 0 ) uniform sampler2D cTextureColor;
layout( binding = 1 ) uniform sampler2D cMosaicTextureAlb;
layout( binding = 2 ) uniform sampler2D cMosaicTextureNrm;
layout( binding = 3 ) uniform sampler2D cMosaicTextureRgh;
layout( binding = 4 ) uniform sampler2D cNoiseTexture;

//------------------------------------------------------------------------------
// 頂点シェーダ
//------------------------------------------------------------------------------
#if defined( AGL_VERTEX_SHADER )

layout (location = 0) in vec3 aPosition;	// @@ id="_p0" hint="position0"
layout ( location = 1 ) in vec2 aTexCoord1;
out vec2 vTexCoord;
out vec2 vScreen;

void main()
{
	VERTEX_SHADER_QUAD_TRIANGLE__CALC_POS_TEX
	VERTEX_SHADER_QUAD_TRIANGLE__CALC_SCREEN
}

//------------------------------------------------------------------------------
// フラグメントシェーダ
//------------------------------------------------------------------------------
#elif defined( AGL_FRAGMENT_SHADER )

// 出力変数
layout( location = 0 )	out vec4 oColor;
in vec2 	vTexCoord;
in vec2 	vScreen;

void main()
{
#if ( PASS == 0 )
	vec3 alb = texture( cTextureColor, vTexCoord ).rgb;
	oColor = vec4( alb, 1.0 );
#else
	vec2 tile_coord = vTexCoord;
	tile_coord.x *= uParams1.w;
	tile_coord.y *= uParams2.w;

	vec3 alb     = texture( cTextureColor, vTexCoord ).rgb;
	float alpha  = texture( cMosaicTextureAlb, tile_coord ).a;
	vec2 tex_nrm = texture( cMosaicTextureNrm, tile_coord ).rg;
	float rgh    = texture( cMosaicTextureRgh, tile_coord ).r;

	vec3 bump;
	decodeNormalMap(bump, tex_nrm, false);
	vec3 nrm;
	calcNormalByBumpTBN(nrm, bump, vec3(1.0, 0.0, 0.0), vec3(0.0, 1.0, 0.0), vec3(0.0, 0.0, 1.0));

	FragInfo frag;
	frag.N = nrm;
	frag.view_pos.z = -( 0.1 * cRange + cNear );
	frag.view_pos.xy = vScreen.xy * frag.view_pos.z;

	float noise = texture( cNoiseTexture, tile_coord ).r;
	alb = mix(alb, alb * noise, uParams4.w);
	alb = mix(alb, uParams5.xyz, alpha);
	setMaterialParam(frag, alb, rgh, 0.0);
	frag.V = normalize(-frag.view_pos);
	calcN_V(frag);

	vec3 light_buf_color = vec3(0.0);

	// 直接光1の計算
	{
		vec4 specular_color = vec4(0.0);
		float diffuse = calcDiffuseIntensity(frag.N, uParams3.xyz);
		vec3 dir_light_color = uParams1.xyz;

		LightInfo light;
		InitLightInfo(light);
		light.spc_scale = 1.0;
		light.L = uParams3.xyz;
		calcN_L(light, frag);
		calcN_H(frag, light);
		calcN_V(frag);
		calcSpecularGGX(frag, light);
		vec3 refrect_color = mix(vec3(1.0), frag.base_color.rgb, frag.metalness);
		specular_color.rgb += refrect_color * light.spc_intensity * dir_light_color;
		vec3 diffuse_color = vec3(0.0);
		diffuse_color = dir_light_color * frag.albedo_color.rgb * diffuse;
		light_buf_color += specular_color.rgb + diffuse_color;
	}

	// 直接光2の計算
	{
		vec4 specular_color = vec4(0.0);
		float diffuse = calcDiffuseIntensity(frag.N, uParams4.xyz);
		vec3 dir_light_color = uParams2.xyz;

		LightInfo light;
		InitLightInfo(light);
		light.spc_scale = 1.0;
		light.L = uParams4.xyz;
		calcN_L(light, frag);
		calcN_H(frag, light);
		calcN_V(frag);
		calcSpecularGGX(frag, light);
		vec3 refrect_color = mix(vec3(1.0), frag.base_color.rgb, frag.metalness);
		specular_color.rgb += refrect_color * light.spc_intensity * dir_light_color;
		vec3 diffuse_color = vec3(0.0);
		diffuse_color = dir_light_color * frag.albedo_color.rgb * diffuse;
		light_buf_color += specular_color.rgb + diffuse_color;
	}

	// 露出
	light_buf_color *= uParams3.w;

	// トーンマップ処理
	vec3 tone_map_color;
	vec4 coeff = ( light_buf_color.r < uCrossOver ) ? uToeCoeff : uSholuderCoeff;
	vec2 fract = coeff.xy * light_buf_color.r + coeff.zw;
	tone_map_color.r = fract.x / fract.y;
	coeff = ( light_buf_color.g < uCrossOver ) ? uToeCoeff : uSholuderCoeff;
	fract = coeff.xy * light_buf_color.g + coeff.zw;
	tone_map_color.g = fract.x / fract.y;
	coeff = ( light_buf_color.b < uCrossOver ) ? uToeCoeff : uSholuderCoeff;
	fract = coeff.xy * light_buf_color.b + coeff.zw;
	tone_map_color.b = fract.x / fract.y;

	oColor = vec4( tone_map_color, 1.0 );
#endif
}
#endif // defined( AGL_FRAGMENT_SHADER )

