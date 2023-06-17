/**
 * @file	alHdrCompose.glsl
 * @author	Matsuda Hirokazu  (C)Nintendo
 *
 * @brief	AGL を参考に、自前でＨＤＲコンポーズ
 */

#include "alMathUtil.glsl"
#include "alDefineVarying.glsl"
#include "alReducedBufferAdjustUtil.glsl" // ぴったり君

#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable // 明示的な場所指定には必要。無いと GPU ハング。
#endif

#define RENDER_TYPE			(0) // @@ id="cRenderType" choice="0,1" default="0"
#define RENDER_STD			(0)
#define RENDER_DISTORTION	(1)
#if (RENDER_TYPE == RENDER_DISTORTION)
#include "alVrDistortionUtil.glsl"
#include "alVrRenderLimitUtil.glsl"
#endif // RENDER_TYPE

#define USING_CARTOON		(0) // @@ id="cUsingCartoon" choice="0,1" default="0"

#define EFFECT_TYPE			(0) // @@ id="cEffectType" choice="0,1,2,3" default="0"
#define EFFECT_NONE			(0)
#define EFFECT_ONLY_COMPOSE	(1)
#define EFFECT_ONLY_MASK	(2)
#define EFFECT_BOTH			(3)

#define CAMERA_MASK_TYPE	(0) // @@ id="CameraMaskType" choice="0,1" default="0"
#define CAMERA_MASK_ONLY	(0)
#define CAMERA_MASK_DIFFUSE	(1)

#define TONE_MAP_TYPE			(0) // @@ id="cToneMapType" choice="0,1,2,3,4,5,6,7,8" default="0"
#define TONE_MAP_LINEAR			(0)
#define TONE_MAP_EXPOSURE		(1)
#define TONE_MAP_EXPOSURE_ATMOS	(2)
#define TONE_MAP_EXPOSURE_COEF	(3)
#define TONE_MAP_REINHARD		(4)
#define TONE_MAP_FILMIC			(5)
#define TONE_MAP_POW			(6)
#define TONE_MAP_FILMIC_PARAM	(7)
#define TONE_MAP_S_CURVE		(8)

#define COLOR_CORRECTION_TYPE	(0) // @@ id="cColorCorrectionType" choice="0,1" default="0"
#define COLOR_CORRECTION_NONE	(0)
#define COLOR_CORRECTION_USE	(1)

#define INDIRECT_TYPE	(0) // @@ id="IndirectType" choice="0,1,2" default="0"
#define INDIRECT_NONE	(0)
#define INDIRECT_USE	(1)
#define INDIRECT_TWO	(2)

#define CHROMATIC_ABERRATION	(0) // @@ id="ChromaticAberration" choice="0,1" default="0"

#define REDUCED_BUFFER_TYPE				(0) // @@ id="cReducedBufferType" choice="0,1" default="0"
#define REDUCED_BUFFER_NONE				(0)
#define REDUCED_BUFFER_EFFECT_LDR		(1)

#define IS_USE_ADJUST_REDUCE_BUFFER		(0) // @@ id="cIsUseAdjustReduceBuffer" choice="0,1" default="0"
#define IS_OUTPUT_LUMA					(0) // @@ id="cIsOutputLuma" choice="0,1" default="0"
#define IS_COMPOSE_CAMERA_BLUR			(0) // @@ id="cIsComposeCameraBlur" choice="0,1" default="0"

layout(std140, binding = 1)
uniform HdrComposeInfo
{
	vec4	uCameraMaskDiffuse;
	float	uExposure;
	float	uCameraMaskBase;
	float	uCameraMaskScale;
	float	uCameraIndirectScale;
	float	uCameraIndirect2Scale;
	float	uChromaticAberrationSize;
	vec2	uCameraMaskTexOffset;
	vec2	uCameraMaskTexScale;
	vec2	uCameraIndirectOffset;
	vec2	uCameraIndirect2Offset;
	vec2	uCameraIndirectTexScale;
	vec2	uCameraIndirect2TexScale;
	vec2	uColorCorrectionCoeff;
	vec3	uToneMapPowBase;
	float	uToonShadeRate;
	vec3	uToonStep;
	vec3	uToonWidth;
	float	uShoulderStrength;
	float	uLinearStrength;
	float	uLinearAngle;
	float	uToeStrength;
	float	uToeNumerator;
	float	uToeDenominator;
	float	uCrossOver;
	vec4	uToeCoeff;
	vec4	uSholuderCoeff;
	vec4	uLumaCoeff;
};

#define BINDING_SAMPLER_HDR					layout(binding = 0)
#define BINDING_SAMPLER_EXPOSURE			layout(binding = 1)
#define BINDING_SAMPLER_COLOR_CORRECTION	layout(binding = 2)
#define BINDING_SAMPLER_CAMERA_MASK			layout(binding = 3)

#define BINDING_SAMPLER_COMPOSE				layout(binding = 4)
#define BINDING_SAMPLER_COMPOSE_WITH_MASK	layout(binding = 5)

#define BINDING_SAMPLER_INDIRECT			layout(binding = 6)
#define BINDING_SAMPLER_INDIRECT2			layout(binding = 7)
#define BINDING_SAMPLER_REDUCE_BUFFER		layout(binding = 8)

#define BINDING_SAMPLER_DEPTH				layout(binding = 9)
#define BINDING_SAMPLER_HALF_DEPTH			layout(binding = 10)

#define BINDING_SAMPLER_CAMERA_BLUR			layout(binding = 11)

BINDING_SAMPLER_HDR					uniform sampler2D uHdrImage;
BINDING_SAMPLER_EXPOSURE			uniform sampler2D uExposureTexture;
BINDING_SAMPLER_COLOR_CORRECTION	uniform sampler3D uColorCorrectionTable;
BINDING_SAMPLER_CAMERA_MASK			uniform sampler2D uCameraMask;

BINDING_SAMPLER_COMPOSE				uniform sampler2D uCompose;
BINDING_SAMPLER_COMPOSE_WITH_MASK	uniform sampler2D uComposeWithMask;

BINDING_SAMPLER_INDIRECT			uniform sampler2D uCameraIndirect;
BINDING_SAMPLER_INDIRECT2			uniform sampler2D uCameraIndirect2;

BINDING_SAMPLER_REDUCE_BUFFER		uniform sampler2D uEffectReducedBuffLdr;

BINDING_SAMPLER_CAMERA_BLUR			uniform sampler2D uCameraBlurFrame;

// ぴったり君
#if (IS_USE_ADJUST_REDUCE_BUFFER == 1)
BINDING_SAMPLER_DEPTH				uniform sampler2D cViewDepth;
BINDING_SAMPLER_HALF_DEPTH			uniform sampler2D cHalfViewDepth;

uniform float uNear;
uniform float uInvRange;
#endif 

// カメラブラー
#if (IS_COMPOSE_CAMERA_BLUR == 1)
uniform vec4		uVignettingParam;
uniform vec4		uVignettingParam2;
#endif

//------------------------------------------------------------------------------
// 頂点シェーダ
//------------------------------------------------------------------------------
#if defined(AGL_VERTEX_SHADER)

layout (location=0) in vec4 aPosition;	// @@ id="_p0" hint="position0"
layout (location=1) in vec2 aTexCoord;

out vec2	vTexCoord;
out vec2	vMaskCoord;
out vec2	vIndCoord;
out vec2	vInd2Coord;
out vec4	vExposure;

out vec4	vVignettingParam;

void main()
{
#if (RENDER_TYPE == RENDER_DISTORTION)
	int vtx_id = gl_VertexID;
	int poly_num = int(uFarPolyNum.y);
	float far = uFarPolyNum.x;
	calcRenderLimitMeshPositionTriFan(gl_Position, poly_num, vtx_id, far);
	vec2 tex_uv = vec2(gl_Position.xy * 0.5 + 0.5);
	tex_uv.y = 1.0 - tex_uv.y;
	vTexCoord.xy = tex_uv;
#else
	gl_Position.xy = 2.0 * aPosition.xy;
	vTexCoord = aTexCoord;

	gl_Position.z  = 0.0;
	gl_Position.w  = 1.0;

	#if defined( AGL_TARGET_GL )
		vTexCoord.y = 1.0 - vTexCoord.y;
	#endif
#endif // RENDER_TYPE

	// ベースの位置からカメラインダイレクトの座標を決定する。
	#if (INDIRECT_USE <= INDIRECT_TYPE)
	{
		vIndCoord = vTexCoord * uCameraIndirectTexScale + uCameraIndirectOffset;
		#if (INDIRECT_TYPE == INDIRECT_TWO)
		{
			vInd2Coord = vTexCoord * uCameraIndirect2TexScale + uCameraIndirect2Offset;
		}
		#endif // INDIRECT_TWO
	}
	#endif // INDIRECT_TYPE

	// その後にカメラマスクもスクロールしたりして座標を決定する。
	#if ((EFFECT_TYPE == EFFECT_ONLY_MASK) || (EFFECT_TYPE == EFFECT_BOTH))
	{
		vMaskCoord = vTexCoord * uCameraMaskTexScale + uCameraMaskTexOffset;
	}
	#endif

	vExposure = texture(uExposureTexture, vec2(0.0));
	vExposure.a *= uExposure;

#if (IS_USE_ADJUST_REDUCE_BUFFER == 1)
	calcTexCoordReducedBufferAdjust(vTexCoord.xy);
#endif
}

//------------------------------------------------------------------------------
// フラグメントシェーダ
//------------------------------------------------------------------------------
#elif defined(AGL_FRAGMENT_SHADER)

in vec2	vTexCoord;
in vec2	vMaskCoord;
in vec2	vIndCoord;
in vec2	vInd2Coord;
in vec4	vExposure;

#if (RENDER_TYPE == RENDER_DISTORTION)
in vec4	vDistortionInfo;
#endif // RENDER_TYPE


layout(location = 0)	out vec4	oColor;
#if IS_OUTPUT_LUMA
layout(location = 1)	out float	oLuma;
#endif

void main ( void )
{
	float exposure = vExposure.a;

	// インダイレクト使う場合
	vec2 tex_coord = vTexCoord;
	vec2 ind = vec2(0.0);
	const float middle_float = 128.0f / 255.0f;
	#if (INDIRECT_TYPE == INDIRECT_USE)
	{
		ind = (texture(uCameraIndirect, vIndCoord).rg - middle_float) * uCameraIndirectScale;
		tex_coord.xy += ind;
	}
	#elif (INDIRECT_TYPE == INDIRECT_TWO)
	{
		vec2 ind2	= texture(uCameraIndirect2, vInd2Coord).rg;
		vec2 ind_crd = vIndCoord + (ind2 - middle_float) * uCameraIndirect2Scale;
		ind	= (texture(uCameraIndirect, ind_crd).rg - middle_float) * uCameraIndirectScale;
		tex_coord.xy += ind;
	}
	#endif // INDIRECT_TYPE

	float RI = 1.0;
	#if (RENDER_TYPE == RENDER_DISTORTION)
	{
		calcDistortedUv_Fs(RI, tex_coord);
		tex_coord += UV_OFFSET;
	}
	#endif

	vec4 hdr_color = texture(uHdrImage, tex_coord);

	// カメラブラー合成
	#if (IS_COMPOSE_CAMERA_BLUR == 1)
	{
		vec2 center_pos = uVignettingParam2.xy;
		float len = length(tex_coord - center_pos) * 2.0;
		float range = clamp01( len - uVignettingParam.y );
		float vignet = clamp01( range / (1.0 - uVignettingParam.y) );
		float blur_size = mix( 1.0, uVignettingParam2.z, uVignettingParam.z );
		float level = min( log2( blur_size ), uVignettingParam.w ) * uVignettingParam2.w;
		float alpha = clamp01( level + 1.0 );
		vec3 rgb = textureLod( uCameraBlurFrame, tex_coord, level * vignet ).rgb;
		alpha = alpha * vignet + uVignettingParam.x * range;
		hdr_color.rgb = mix(hdr_color.rgb, rgb, clamp01(alpha));
	}
	#endif

	// インダイレクトで色収差
	#if (INDIRECT_TYPE != INDIRECT_NONE && CHROMATIC_ABERRATION == 1)
	{
		if (ind != vec2(0.0))
		{
			hdr_color.r = texture(uHdrImage, tex_coord + (ind * (uChromaticAberrationSize * 2))).r;
			hdr_color.g = texture(uHdrImage, tex_coord + (ind * uChromaticAberrationSize)).g;
		}
	}
	#endif

	hdr_color.rgb *= exposure;

	vec3 light_buf = vec3(0.0);

	#if (EFFECT_TYPE == EFFECT_ONLY_COMPOSE)
	{
		// カメラマスク無し
		light_buf += texture(uCompose, tex_coord).rgb;
	}
	#elif ((EFFECT_TYPE == EFFECT_ONLY_MASK) || (EFFECT_TYPE == EFFECT_BOTH))
	{
		// マスクありとマスクなし
		#if (EFFECT_TYPE == EFFECT_BOTH)
		{
			light_buf += texture(uCompose, tex_coord).rgb;
		}
		#endif // (EFFECT_TYPE == EFFECT_BOTH)
		
		// マスクだけ
		vec3 orig_mask = texture(uCameraMask, vMaskCoord).rgb;
		
		// ディフューズ
		#if (CAMERA_MASK_TYPE == CAMERA_MASK_DIFFUSE)
		{
			light_buf += orig_mask * uCameraMaskDiffuse.rgb * uCameraMaskDiffuse.a;
		}
		#endif // CAMERA_MASK_DIFFUSE
		
		vec3 mask = vec3(uCameraMaskBase) + orig_mask * uCameraMaskScale;
		light_buf += texture(uComposeWithMask, tex_coord).rgb * mask;
	}
	#endif

	// ライトバッファにも自動露出補正を反映
	light_buf *= exposure;

	// トーンマップ
	vec3 tone_map_color;
	#if (TONE_MAP_TYPE == TONE_MAP_LINEAR) //リニア
	{
		tone_map_color = hdr_color.rgb + light_buf;
	}
	#elif (TONE_MAP_TYPE == TONE_MAP_EXPOSURE) //感光
	{
		tone_map_color = hdr_color.rgb + light_buf;
		tone_map_color = 1.0 - exp(-tone_map_color);
	}
	#elif (TONE_MAP_TYPE == TONE_MAP_EXPOSURE_ATMOS) //感光亜種
	{
		tone_map_color = hdr_color.rgb + light_buf;
		tone_map_color.r = tone_map_color.r < 1.413 ? pow(tone_map_color.r * 0.38317, 1.0/2.2) : 1.0 - exp(-tone_map_color.r);
		tone_map_color.g = tone_map_color.g < 1.413 ? pow(tone_map_color.g * 0.38317, 1.0/2.2) : 1.0 - exp(-tone_map_color.g);
		tone_map_color.b = tone_map_color.b < 1.413 ? pow(tone_map_color.b * 0.38317, 1.0/2.2) : 1.0 - exp(-tone_map_color.b);
	}
	#elif (TONE_MAP_TYPE == TONE_MAP_REINHARD) //ラインハルト
	{
		tone_map_color = hdr_color.rgb + light_buf;
		tone_map_color = tone_map_color / ( 1.0 + tone_map_color );
	}
	#elif (TONE_MAP_TYPE == TONE_MAP_FILMIC) //フィルミック
	{
		vec3 raw_color = hdr_color.rgb + light_buf;
		tone_map_color = max( raw_color - 0.004, 0.0 );
		vec3 tmp = raw_color * 6.2;
		tone_map_color = ( raw_color * ( tmp + 0.5 ) ) / ( raw_color * ( tmp + 1.7 ) + 0.06 );
	}
	#elif (TONE_MAP_TYPE == TONE_MAP_FILMIC_PARAM) //フィルミック[パラメータ]
	{
		vec3 raw_color = hdr_color.rgb + light_buf;
		tone_map_color = ((raw_color*(uShoulderStrength*raw_color+uLinearAngle*uLinearStrength)+uToeStrength*uToeNumerator)/(raw_color*(uShoulderStrength*raw_color+uLinearStrength)+uToeStrength*uToeDenominator))-uToeNumerator/uToeDenominator;
	}
	#elif (TONE_MAP_TYPE == TONE_MAP_POW) //感光パワー
	{
		tone_map_color = hdr_color.rgb + light_buf;
		tone_map_color = 1.0 - pow(uToneMapPowBase, -tone_map_color);
	}
	#elif (TONE_MAP_TYPE == TONE_MAP_EXPOSURE_COEF)	//感光(係数)
	{
		tone_map_color = hdr_color.rgb + light_buf;
		tone_map_color = 1.0 - exp(-uToneMapPowBase*tone_map_color);
	}
	#elif (TONE_MAP_TYPE == TONE_MAP_S_CURVE) //S-CURVE
	{
		vec3 raw_color = hdr_color.rgb + light_buf;
		vec4 coeff = ( raw_color.r < uCrossOver ) ? uToeCoeff : uSholuderCoeff;
		vec2 fract = coeff.xy * raw_color.r + coeff.zw;
		tone_map_color.r = fract.x / fract.y;
		coeff = ( raw_color.g < uCrossOver ) ? uToeCoeff : uSholuderCoeff;
		fract = coeff.xy * raw_color.g + coeff.zw;
		tone_map_color.g = fract.x / fract.y;
		coeff = ( raw_color.b < uCrossOver ) ? uToeCoeff : uSholuderCoeff;
		fract = coeff.xy * raw_color.b + coeff.zw;
		tone_map_color.b = fract.x / fract.y;
	}
	#endif // TONE_MAP_TYPE

	// 縮小バッファのブレンド合成(LDR)
	#if (REDUCED_BUFFER_TYPE == REDUCED_BUFFER_EFFECT_LDR)
	{
		vec2 tex_coord_reduce_buf = tex_coord;
		#if (IS_USE_ADJUST_REDUCE_BUFFER == 1)
		{
			float full_depth = texture(cViewDepth, tex_coord).r;
			calcReducedBufferAdjustUV(tex_coord_reduce_buf, full_depth, cHalfViewDepth, tex_coord, uNear, uInvRange);
		}
		#endif

		vec4 reduced_buffer = texture(uEffectReducedBuffLdr, tex_coord_reduce_buf);
		tone_map_color = reduced_buffer.rgb + tone_map_color * reduced_buffer.a;
	}
	#endif // RENDER_BUFFER_TYPE

	// カラーコレクション
	#if (COLOR_CORRECTION_TYPE == COLOR_CORRECTION_USE)
	{
		vec3 xyz = tone_map_color * uColorCorrectionCoeff.x + uColorCorrectionCoeff.y;
		tone_map_color = texture(uColorCorrectionTable, xyz).rgb;
	}
	#endif // COLOR_CORRECTION_USE
	
	// カートゥーンはトーンマップ後に計算するのでポストエフェクトにもかかってしまう
	#if (USING_CARTOON == 1)
	{
		// 輝度を求める。トーンマップにより範囲は [0, 1] であるはず。
		const vec3 coef_lumi = vec3(0.298912, 0.586611, 0.114477);
		float lumi = clamp01(dot(tone_map_color, coef_lumi));
		vec3 dark = tone_map_color * tone_map_color * tone_map_color * tone_map_color;

		vec3 rate3 = smoothstep(uToonStep, uToonStep + uToonWidth, vec3(lumi));
		float rate = (rate3.x + rate3.y + rate3.z) * 0.33333;
		/*
		float rate = smoothstep(uToonCoef.x, uToonCoef.y, lumi) * 0.333;
		rate += smoothstep(uToonCoef.z, uToonCoef.w, lumi) * 0.333;
		rate += smoothstep(uToonCoef2.x, uToonCoef2.y, lumi) * 0.333;
		*/
		tone_map_color = mix(dark, tone_map_color, max(clamp01(rate), clamp01(1.0 - uToonShadeRate)));
	}
	#endif // USING_CARTOON

	oColor.rgb = tone_map_color;
	oColor.a = hdr_color.a;

	#if IS_OUTPUT_LUMA
	{
		oLuma = oColor.r * uLumaCoeff.x + oColor.g * uLumaCoeff.y + oColor.b * uLumaCoeff.z;
	}
	#endif
	
	#if (RENDER_TYPE == RENDER_DISTORTION)
	{
		oColor.rgb *= RI;
	}
	#endif // RENDER_TYPE
}

#endif // AGL_FRAGMENT_SHADER
