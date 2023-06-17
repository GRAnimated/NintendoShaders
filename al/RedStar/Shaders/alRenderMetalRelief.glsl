/**
 * @file	alRenderMetalRelief.glsl
 * @author	Yosuke Mori  (C)Nintendo
 *
 * @brief	金属レリーフ描画
 */

#define IS_USE_TEXTURE_BIAS (0)

#include "alDeclareUniformBlockBinding.glsl"
#include "alDefineVarying.glsl"
#include "alDeclareMdlEnvView.glsl"
#include "alMathUtil.glsl"
#include "alGBufferUtil.glsl"
#include "alLightingFunction.glsl"
#include "alScreenUtil.glsl"
#include "alCalcNormal.glsl"
#include "alCalcLighting.glsl"

layout( binding = 0 ) uniform sampler2D cWorldNormal;
layout( binding = 1 ) uniform sampler2D cViewDepth;
layout( binding = 2 ) uniform sampler2D cCoinTextureAlb;

uniform vec4 uMetalParams1; //xyz:color       w:metalness
uniform vec4 uMetalParams2; //xyz:light_color w: roughness
uniform vec4 uMetalParams3; //xyz:light_dir   w: exposure
uniform vec4 uMetalParams4; //xyz:light_dir2  w: look_at
uniform vec4 uMetalParams5; //x: coin_roughness y: roughness_scale z: normal_scale w:coin_normal_base
uniform vec4 uMetalParams6; //xyz:light_color2 w: coin_y_offset
uniform vec4 uMetalParams7; //xyz:spc_color1 w: coin_nrm_rate
uniform vec4 uMetalParams8; //xyz:spc_color2 w: coin_nrm_curve
uniform float uCoinRange;
uniform float uAlbedoRange;
uniform	float uCrossOver;
uniform	vec4 uToeCoeff;
uniform	vec4 uSholuderCoeff;

//------------------------------------------------------------------------------
// 頂点シェーダ
//------------------------------------------------------------------------------
#if defined(AGL_VERTEX_SHADER)

layout ( location = 0 ) in vec4 aPosition;	// @@ id="_p0" hint="position0"
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
#elif defined(AGL_FRAGMENT_SHADER)

out	vec4	oColor;
in vec2 	vTexCoord;
in vec2 	vScreen;

void main()
{
	FragInfo frag;
	GBufferInfo g_buf;
	float depth = texture(cViewDepth, vTexCoord).r;
	decodeWorldNrm(g_buf, cWorldNormal, vTexCoord);
	frag.N = rotMtx34Vec3(cView, g_buf.normal);
	if (depth > 0.99)
	{
		frag.N = vec3(0.0, 0.0, 1.0);
	}
	
	frag.view_pos.z = -( depth * cRange + cNear );
	frag.view_pos.xy = vScreen.xy * frag.view_pos.z;

	vec2 tex_coord = vTexCoord * 2.0 - 1.0;
	vec2 length_coord = tex_coord;
	length_coord.x *= 16.0 / 9.0;
	float length = length( length_coord - vec2( 0.0, uMetalParams6.w ) );
	float roughness = uMetalParams2.w;

	// コインノーマルの生成
	vec3 coin_nrm = vec3(0.0, 0.0, 1.0);
	coin_nrm.x = tex_coord.x >= 0.0 ? (exp(tex_coord.x * uMetalParams8.w) - 1.0) * uMetalParams7.w : (exp(-tex_coord.x * uMetalParams8.w) - 1.0) * -uMetalParams7.w;
	coin_nrm.y = tex_coord.y >= 0.0 ? (exp(tex_coord.y * uMetalParams8.w) - 1.0) * -uMetalParams7.w  : (exp(-tex_coord.y * uMetalParams8.w) - 1.0) * uMetalParams7.w;
	NORMALIZE_B(coin_nrm, coin_nrm);

	// コインノーマルとの合成
	if (length < uCoinRange)
	{
		float depth_scale = uMetalParams5.y * (-frag.view_pos.z + uMetalParams4.w);
		roughness = clamp01(clamp01(1.0 - exp2(-depth_scale)) * roughness);
		float mix_rate = uMetalParams5.w;
		mix_rate = mix(mix_rate, 1.0, depth);
		frag.N = mix(frag.N, coin_nrm, mix_rate);
		NORMALIZE_B(frag.N, frag.N);
	}
	else
	{
		frag.N = coin_nrm;
		roughness = uMetalParams5.x;
	}
	setMaterialParam(frag, uMetalParams1.xyz, roughness, uMetalParams1.w);

	frag.V = normalize(-frag.view_pos);
	calcN_V(frag);

	vec3 light_buf_color = vec3(0.0);

	// 直接光1の計算
	{
		vec4 specular_color = vec4(0.0);
		float diffuse = calcDiffuseIntensity(frag.N, uMetalParams3.xyz);
		vec3 dir_light_color = uMetalParams2.xyz;

		LightInfo light;
		InitLightInfo(light);
		light.spc_scale = 1.0;
		light.L = uMetalParams3.xyz;
		calcN_L(light, frag);
		calcN_H(frag, light);
		calcN_V(frag);
		calcSpecularGGX(frag, light);
		vec3 refrect_color = mix(vec3(1.0), frag.base_color.rgb, frag.metalness);
		specular_color.rgb += light.spc_intensity * uMetalParams7.rgb;
		vec3 diffuse_color = vec3(0.0);
		diffuse_color = dir_light_color * frag.albedo_color.rgb * diffuse;
		light_buf_color += specular_color.rgb + diffuse_color;
	}

	// 直接光2の計算
	{
		vec4 specular_color = vec4(0.0);
		float diffuse = calcDiffuseIntensity(frag.N, uMetalParams4.xyz);
		vec3 dir_light_color = uMetalParams6.xyz;

		LightInfo light;
		InitLightInfo(light);
		light.spc_scale = 1.0;
		light.L = uMetalParams4.xyz;
		calcN_L(light, frag);
		calcN_H(frag, light);
		calcN_V(frag);
		calcSpecularGGX(frag, light);
		vec3 refrect_color = mix(vec3(1.0), frag.base_color.rgb, frag.metalness);
		specular_color.rgb += light.spc_intensity * uMetalParams8.rgb;
		vec3 diffuse_color = vec3(0.0);
		diffuse_color = dir_light_color * frag.albedo_color.rgb * diffuse;
		light_buf_color += specular_color.rgb + diffuse_color;
	}

	// 露出
	light_buf_color *= uMetalParams3.w;

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

	// 最終出力
	if (length < uAlbedoRange)
	{
		oColor = vec4( tone_map_color, 1.0 );
	}
	else
	{
		vec3 albedo = texture(cCoinTextureAlb, vTexCoord).rgb;
		oColor = vec4( albedo, 1.0 );
	}
}
#endif // defined(AGL_FRAGMENT_SHADER)

