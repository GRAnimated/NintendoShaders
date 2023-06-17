/**
 * @file	alDeferredShading.glsl
 * @author	Yosuke Mori  (C)Nintendo
 *
 * @brief	ディファードシェーディング　最終画像合成
 */

#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable // 明示的な場所指定には必要。無いと GPU ハング。
#extension GL_AMD_texture_texture4 : enable // for PCF   (texture4 関数)
#endif

//for fetchCubeMap
#define IS_USE_TEXTURE_BIAS 0

// シャドウ
#define DEPTH_SHADOW_TYPE					(1) // @@ id="cDepthShadowType"			choice="0,1"	default="1"
#define DEPTH_SHADOW_NONE					(0)
#define DEPTH_SHADOW_PREPASS				(1)

// GGXスペキュラ
#define SPECULAR_GGX_TYPE					(0) // @@ id="cSpecularGGXType"			choice="0,1,2"	default="0"
#define DISABLE_SPECULAR_GGX				(0)
#define ENABLE_SPECULAR_GGX					(1)

// AOの適用
#define AO_TYPE								(0) // @@ id="cAoType"					choice="0,1"	default="0"
#define AO_TYPE_NORMAL						(0)
#define AO_TYPE_BASECOLOR					(1)

// ディレクショナルライト計算をするか
#define IS_CALC_DIR_LIGHT					(1) // @@ id="cIsCalcDirLight"			choice="bool"	default="1"

// ぴったり君テスト
#define IS_USE_ADJUST_REDUCE_BUFFER			(1) // @@ id="cIsUseAdjustReduceBuffer"	choice="bool"	default="1"

// Disney Diffuse
#define IS_USE_DISNEY_DIFFUSE				(0) // @@ id="cIsUseDisneyDiffuse"		choice="bool"	default="0"

// SSAO
#define IS_COMPOSE_SSAO						(0) // @@ id="cIsComposeSSAO"			choice="bool"	default="0"

// フォグ
#define IS_ENABLE_Y_FOG						(0) // @@ id="cIsEnableYFog"			choice="0,1,2"		default="0"
#define IS_ENABLE_Z_FOG						(0) // @@ id="cIsEnableZFog"			choice="0,1,2"		default="0"
#define FOG_BLEND_TYPE						(0) // @@ id="cFogBlendType"			choice="0"			default="0"
#define Y_FOG_DISTANCE_SLOPE				(0) // @@ id="cYFogDistanceSlope"		choice="0,1,2"		default="0"
#define IS_APPLY_SKY						(0) // @@ id="cIsApplySky"				choice="bool"		default="0"

#define FOG_BLEND_TYPE_MIX					(0)
#define FOG_BLEND_TYPE_ZFOG					(1)
#define FOG_BLEND_TYPE_YFOG					(2)
#define FOG_BLEND_TYPE_MIX_LOW				(3)
#define FOG_BLEND_TYPE_MULT					(4)

#define Y_FOG_DISTANCE_NONE					(0)
#define Y_FOG_DISTANCE_DEC					(1)
#define Y_FOG_DISTANCE_INC					(2)

#include "alDeclareUniformBlockBinding.glsl"

#define USING_SCREEN_AND_TEX_COORD_CALC	(1)
#include "alDefineVarying.glsl"
#include "alDeclareMdlEnvView.glsl"
#include "alCalcFullScreenTriangle.glsl"
#include "alMathUtil.glsl"
#include "alReducedBufferAdjustUtil.glsl" // ぴったり君
#include "alHdrUtil.glsl"
#include "alFetchCubeMap.glsl"

// ディレクショナルライトカラー
DECLARE_VARYING(vec4,	vDirLitColor);

// Gバッファ
layout(binding = 0)
uniform sampler2D cBaseColor;

layout(binding = 2)
uniform sampler2D cWorldNormal;

layout(binding = 3)
uniform sampler2D cViewDepth;

layout(binding = 4)
uniform sampler2D cHalfViewDepth;

layout(binding = 6)
uniform samplerCube cTexCubeMapSky;

layout(binding = 7)
uniform sampler2D cPrePassShadow;

layout(binding = 8)
uniform sampler2D cSSAO;

layout(binding = 9)
uniform sampler3D cNoise3D;

layout(binding = 15)
uniform sampler2D cDirectionalLightColor;

BINDING_UBO_OTHER_FIRST	uniform Fog
{
	// フォグ
	vec4	cFogColor;		// .a にはフォグのslope(フォグのかかり具合)
	float	cFogStart;
	float	cFogMax;
	// Y フォグ
	vec4	cYFogColor;		// .a にはフォグのslope(フォグのかかり具合)
	float	cYFogStart;
	float	cYFogMax;
	vec3	cViewAxisY;		// Y 軸方向
	vec3	cViewAxisZ;		// Z 軸方向
	float	cYFogUpStart;	
	float	cYFogUpRate;
	float	cYFogDistScale;

	// LOD
	float	cSkyMip;		// SKYLOD

	// for noise
	vec4 	cNoiseParam; // xyz : tex crd add,  w : tex crd scale
	vec4 	cNoiseParamYFog; // xyz : tex crd add,  w : tex crd scale
	vec4	cNoiseScale; // x : z fog,  y : y fog,  z : z fog dist coef,  w : y fog dist coef

	// コースティクス
	vec4	cCausticsParam;		// x : start,  y : power,  z : caustics tex crd scale,  w : add_y for animation
	vec4 	cCausticsParam2;	// x : intensity,  y : tex crd scale y
};

#define NOISE_TEX_CRD_ADD	cNoiseParam.xyz
#define NOISE_TEX_CRD_SCALE	cNoiseParam.w

#define NOISE_TEX_CRD_ADD_YFOG		cNoiseParamYFog.xyz
#define NOISE_TEX_CRD_SCALE_YFOG	cNoiseParamYFog.w

#define NOISE_INTENSITY			cNoiseScale.x
#define NOISE_INTENSITY_YFOG	cNoiseScale.y
#define NOISE_DIST_COEF			cNoiseScale.z
#define NOISE_DIST_COEF_YFOG	cNoiseScale.w

#define CAUSTICS_START				cCausticsParam.x
#define CAUSTICS_POWER				cCausticsParam.y
#define CAUSTICS_TEX_CRD_ADD_Y		vec3(0.0, cCausticsParam.w, 0.0)
#define CAUSTICS_INTENSITY			cCausticsParam2.x
#define CAUSTICS_TEX_CRD_SCALE_Y	cCausticsParam2.y
#define CAUSTICS_TEX_CRD_SCALE		vec3(cCausticsParam.z, cCausticsParam.z*CAUSTICS_TEX_CRD_SCALE_Y, cCausticsParam.z)

//------------------------------------------------------------------------------
// 頂点シェーダ
//------------------------------------------------------------------------------
#if defined(AGL_VERTEX_SHADER)

layout (location=0) in vec4 aPosition;	// @@ id="_p0" hint="position0"

void main()
{
	// 全画面を覆う三角形
	CalcFullScreenTriPos(gl_Position, aPosition);

	calcScreenAndTexCoord();

	// ディレクショナルライトのカラー
#if (IS_CALC_DIR_LIGHT == 1)
	getVarying(vDirLitColor) = texture(cDirectionalLightColor, vec2(cDirLightViewDirFetchPos.w, 0.5));
#endif

#if (IS_USE_ADJUST_REDUCE_BUFFER == 1)
	calcTexCoordReducedBufferAdjust(vTexCoord.xy);
#endif
}

//------------------------------------------------------------------------------
// フラグメントシェーダ
//------------------------------------------------------------------------------
#elif defined(AGL_FRAGMENT_SHADER)

#include "alLightingFunction.glsl"
#include "alCalcLighting.glsl"

#include "alGBufferUtil.glsl"
#include "alCalcNormal.glsl"

// 出力変数
layout(location = 0)	out vec4 oColor;

void main()
{
	FragInfo frag;
	float full_depth_tex = 0.0;
	#if (IS_CALC_DIR_LIGHT == 1)
	{
		// 各要素を取得
		GBufferInfo g_buf;
		// ベースカラー G-Buffer から情報を抽出
		storeFragInfoByBaseColorGBuffer(frag, g_buf, cBaseColor, getScreenCoord());

		// World法線を取得
		// デカール的に法線をいじる時はNormalize必要かも
		decodeWorldNrm(g_buf, cWorldNormal, getScreenCoord());
		frag.N = rotMtx34Vec3(cView, g_buf.normal);

		#if (SPECULAR_GGX_TYPE >= ENABLE_SPECULAR_GGX || IS_USE_ADJUST_REDUCE_BUFFER == 1 || IS_ENABLE_Z_FOG > 0 || IS_ENABLE_Y_FOG > 0)
		{
			full_depth_tex = texture(cViewDepth, getScreenCoord()).r;
		}
		#endif
	}
	#endif

	// View空間のデプス
	#if ((IS_CALC_DIR_LIGHT == 1 && SPECULAR_GGX_TYPE >= ENABLE_SPECULAR_GGX) || IS_ENABLE_Z_FOG > 0 || IS_ENABLE_Y_FOG > 0)
	{
		frag.view_pos.z = -( full_depth_tex.r * cRange + cNear );
		frag.view_pos.xy = getScreenRay().xy * frag.view_pos.z;
		frag.V = normalize(-frag.view_pos);
	}
	#endif

	// ぴったりくん
	vec2 tex_coord = getScreenCoord();
	#if (IS_USE_ADJUST_REDUCE_BUFFER == 1)
	{
		calcReducedBufferAdjustUV(tex_coord, full_depth_tex, cHalfViewDepth, getScreenCoord(), cNear, cInvRange);
	}
	#endif

	vec3 light_intensity = vec3(1.0);
	float light_buf_scale = 1.0;

	// シャドウプリパス
	float depth_shadow_factor = 1.0;
	#if (DEPTH_SHADOW_TYPE == DEPTH_SHADOW_PREPASS)
	{
		vec4 shadow_buf = texture(cPrePassShadow, tex_coord).rgba;
		depth_shadow_factor	= shadow_buf.r;
		#if (AO_TYPE == AO_TYPE_NORMAL)
		{
			light_intensity = vec3(shadow_buf.a);
			light_buf_scale = shadow_buf.a;
		}
		#elif (AO_TYPE == AO_TYPE_BASECOLOR)
		{
			light_intensity = mix(frag.base_color.rgb, vec3(round(shadow_buf.a)), abs(vec3(shadow_buf.a) * 2.0 - vec3(1.0)));
			light_buf_scale = shadow_buf.a;
		}
		#endif
	}
	#endif

	// SSAO
	#if (IS_COMPOSE_SSAO == 1)
	{
		float ssao = texture(cSSAO, tex_coord).r;
		vec3 ssao_intensity = mix(frag.base_color.rgb, vec3(round(ssao)), abs(vec3(ssao) * 2.0 - vec3(1.0)));
		light_intensity = min(light_intensity, ssao_intensity);
		light_buf_scale = min(ssao, light_buf_scale);
	}
	#endif

	vec3 final_color = vec3(0.0);

	// ディレクショナルライト
	#if (IS_CALC_DIR_LIGHT == 1)
	{
		vec4 specular_color = vec4(0.0);
		float diffuse = calcDiffuseIntensity(frag.N, cDirLightViewDirFetchPos.xyz);
		vec3 dir_light_color = getVarying(vDirLitColor).rgb;
		dir_light_color *= depth_shadow_factor * light_intensity;

		#if (SPECULAR_GGX_TYPE >= ENABLE_SPECULAR_GGX)
		{
			LightInfo light;
			InitLightInfo(light);
			light.spc_scale = 1.0;
			light.L = cDirLightViewDirFetchPos.xyz;
			calcN_L(light, frag);
			calcN_H(frag, light);
			calcN_V(frag);
			calcSpecularGGX(frag, light);
			vec3 refrect_color = mix(vec3(1.0), frag.base_color.rgb, frag.metalness);
			specular_color.rgb += refrect_color
								 * light.spc_intensity
								 * dir_light_color 
								 * depth_shadow_factor
								;
		}
		#endif
		// ライトとアルベドの計算
		vec3 diffuse_color = vec3(0.0);
		#if (IS_USE_DISNEY_DIFFUSE == 1)
		{
			vec3 half_vec = cDirLightViewDirFetchPos.xyz + frag.V;
			NORMALIZE_EB(half_vec, half_vec);
			float L_H = clamp01(dot(cDirLightViewDirFetchPos.xyz, half_vec));
			float N_L = clamp01(dot(frag.N, cDirLightViewDirFetchPos.xyz));
			float N_V = clamp01(dot(frag.N, frag.V));
			float fd90 = 0.5 + 2.0 * L_H * L_H * frag.roughness.x;
			float FL = pow((1.0 - N_L), 5.0);
			float FV = pow((1.0 - N_V), 5.0);
			diffuse_color = dir_light_color * frag.albedo_color.rgb * INV_PI * (1.0 + (fd90 - 1.0) * FL) * (1.0 + (fd90 - 1.0) * FV);
		}
		#else
		{
			diffuse_color = dir_light_color * frag.albedo_color.rgb * diffuse;
		}
		#endif
		final_color = specular_color.rgb + diffuse_color;
	}
	#endif

	// フォグ
	float transmittance = 1.0;
	#if (IS_ENABLE_Z_FOG > 0 || IS_ENABLE_Y_FOG > 0)
	{
		float fog_intensity = 0.0;
		vec3 pos_w = multMtx34Vec3(cInvView, frag.view_pos);
		#if (IS_ENABLE_Z_FOG > 0)
			float fog_dist_intensity = cFogColor.a * (-frag.view_pos.z + cFogStart);
			fog_intensity = clamp01(clamp01(1.0 - exp2(-fog_dist_intensity)) * cFogMax);
		#endif

		float y_fog_intensity = 0.0;
		float dot_y = dot(frag.view_pos, cViewAxisY);
		#if (IS_ENABLE_Y_FOG > 0)
			float fog_start = cYFogStart-1;
			float fog_pow   = cYFogColor.a;
			float y_fog_dist_intensity = fog_pow * (-dot_y + fog_start);
			y_fog_intensity = clamp01(clamp01(1.0 - exp2(-y_fog_dist_intensity)) * cYFogMax);

			#if (Y_FOG_DISTANCE_SLOPE == Y_FOG_DISTANCE_DEC)
			{
				y_fog_intensity *= clamp01(exp2(frag.view_pos.z * cYFogDistScale));
			}
			#elif (Y_FOG_DISTANCE_SLOPE == Y_FOG_DISTANCE_INC)
			{
				y_fog_intensity *= clamp01(1.0 - exp2(frag.view_pos.z * cYFogDistScale));
			}
			#endif
		#endif

		if(fog_intensity + y_fog_intensity >= 0.00001)
		{
			// ノイズテクスチャ適用
			#if (IS_ENABLE_Z_FOG == 2)
			{
				float nz_fog = texture(cNoise3D, pos_w*NOISE_TEX_CRD_SCALE + NOISE_TEX_CRD_ADD).r - 0.5;
				nz_fog *= clamp01(exp2(-fog_dist_intensity*NOISE_DIST_COEF));
				fog_intensity = clamp01(fog_intensity + fog_intensity*nz_fog*NOISE_INTENSITY);
			}
			#endif
			// ノイズテクスチャ適用
			#if (IS_ENABLE_Y_FOG == 2)
			{
				float nz_yfog = texture(cNoise3D, pos_w*NOISE_TEX_CRD_SCALE_YFOG + NOISE_TEX_CRD_ADD_YFOG).r - 0.5;
				nz_yfog *= clamp01(exp2(-y_fog_dist_intensity*NOISE_DIST_COEF_YFOG));
				y_fog_intensity = clamp01(y_fog_intensity + y_fog_intensity*nz_yfog*NOISE_INTENSITY_YFOG);
			}
			#endif

			vec3 final_fog_color = vec3(1.0);

			#if (FOG_BLEND_TYPE == FOG_BLEND_TYPE_MIX)
			{
				float sum_fog_intensity = fog_intensity + y_fog_intensity + 0.00001; //0割を防ぐ
				float mix_rate = fog_intensity / sum_fog_intensity;
				final_fog_color = mix(cYFogColor.rgb, cFogColor.rgb, mix_rate);
				transmittance = clamp01((1.0 - fog_intensity) * (1.0 - y_fog_intensity));
			}
			#elif (FOG_BLEND_TYPE == FOG_BLEND_TYPE_ZFOG)
			{
				final_fog_color = (y_fog_intensity == 0.0) ? cFogColor.rgb : mix(cYFogColor.rgb , cFogColor.rgb, fog_intensity);
				transmittance = clamp01((1.0 - fog_intensity) * (1.0 - y_fog_intensity));
			}
			#elif (FOG_BLEND_TYPE == FOG_BLEND_TYPE_YFOG)
			{
				final_fog_color = (fog_intensity == 0.0) ? cYFogColor.rgb : mix(cFogColor.rgb , cYFogColor.rgb, y_fog_intensity);
				transmittance = clamp01((1.0 - fog_intensity) * (1.0 - y_fog_intensity));
			}
			#elif (FOG_BLEND_TYPE == FOG_BLEND_TYPE_MIX_LOW)
			{
				final_fog_color = (cYFogColor.rgb + cFogColor.rgb) * 0.5;
				transmittance = clamp01((1.0 - fog_intensity) * (1.0 - y_fog_intensity));
			}
			#elif (FOG_BLEND_TYPE == FOG_BLEND_TYPE_MULT)
			{
				float sum_fog_intensity = fog_intensity + y_fog_intensity + 0.0001; //0割を防ぐ
				float mix_rate = fog_intensity / sum_fog_intensity;
				final_fog_color = mix(cYFogColor.rgb, cFogColor.rgb, mix_rate);
				transmittance = clamp01(1.0 - fog_intensity * y_fog_intensity);
			}
			#endif

			// フォグを空の色になじませる
			#if IS_APPLY_SKY
			{
				vec4 sky_color = vec4(0.0);
				vec3 eye_to_pos = normalize(frag.view_pos);
				vec3 fetch_dir = rotMtx33Vec3(cInvView, eye_to_pos);
				fetchCubeMapConvertHdr(sky_color, cTexCubeMapSky, fetch_dir, cSkyMip);
				final_fog_color =  final_fog_color * sky_color.rgb;
			}
			#endif

			final_color = (final_fog_color * (1.0 - transmittance)) + final_color * transmittance;
		}
	}
	#endif

	CLAMP_LIGHTBUF(final_color, final_color);

	oColor = vec4(final_color, light_buf_scale * transmittance);
}

#endif
