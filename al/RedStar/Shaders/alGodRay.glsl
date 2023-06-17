/**
 * @file	alGodRay.glsl
 * @author	Matsuda Hirokazu  (C)Nintendo
 *
 * @brief	ゴッドレイ
 */

#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable // 明示的な場所指定には必要。無いと GPU ハング。
#endif

#include "alMathUtil.glsl"

// バリエーション
#define	RENDER_TYPE					(0) // @@ id="cRenderType"
#define MAKE_BLUR					(0)
#define MAKE_MASK					(1)
#define COMPOSE						(2)

#define BLUR_QUALITY				(0) // @@ id="BlurQuality"


// マスク作成時にデプスを使用するかどうか
#define MASK_DEPTH_TYPE				(0) // @@ id="MaskDepthType"
#define MASK_DEPTH_FAR				(0)
#define MASK_DEPTH_VALUE			(1)
#define MASK_DEPTH_NONE				(2)

// マスク作成時に距離を使用するかどうか
#define MASK_DISTANCE_TYPE			(0) // @@ id="MaskDistanceType"
#define MASK_DISTANCE_NONE			(0)
#define MASK_DISTANCE_USE			(1)

// マスク作成時に閾値使用するかどうか
#define THRESHOLD_TYPE				(0) // @@ id="ThresholdType"
#define THRESHOLD_NONE				(0)
#define THRESHOLD_USE				(1)

// モデルマスクバッファを使うかどうか
#define MODEL_MASK_TYPE				(0) // @@ id="ModelMaskType"
#define MODEL_MASK_NONE				(0)
#define MODEL_MASK_USE				(1)

layout(binding = 0)
uniform sampler2D uTexture;

layout(binding = 1)
uniform sampler2D uDepth;

layout(binding = 2)
uniform sampler2D uTexture1;

layout(binding = 3)
uniform sampler2D uTexture2;


layout(std140, binding = 2)
uniform GodRayInfo
{
	vec4	uComposeColor;
	vec2	uBlurCenter;
	vec2	uDeltaTexel;
	float	uBlurPower;		// ブラーの強さ
	float	uMaskRadius;	// 中心からの半径の２乗
	float	uInvMaskRadius;	// 半径の逆数
	float	uMaskDepth;
	float	uMaskDepthMax;
	float	uThreshold;
	float	uAspect;
};

#define SAMPLE_NUM	(9*(BLUR_QUALITY+1))

//------------------------------------------------------------------------------
// 頂点シェーダ
//------------------------------------------------------------------------------
#if defined(AGL_VERTEX_SHADER)

layout (location=0) in vec3 aPosition;				// @@ id="_p0" hint="position0"

out vec2 vTexCoord;

void main()
{
	vec2 sign_pos = sign(aPosition.xy); // 画面を覆う -1 〜 1 の範囲のスクリーン座標になる
	gl_Position.xy = sign_pos;
	gl_Position.z = 0;
	gl_Position.w = 1.0;

	vTexCoord.x =  sign_pos.x * 0.5 + 0.5;
	vTexCoord.y = -sign_pos.y * 0.5 + 0.5;

#if defined( AGL_TARGET_GL )
	vTexCoord.y = 1.0 - vTexCoord.y;
#endif
}

//------------------------------------------------------------------------------
// フラグメントシェーダ
//------------------------------------------------------------------------------
#elif defined(AGL_FRAGMENT_SHADER)

in vec2 vTexCoord;

#if (THRESHOLD_TYPE == THRESHOLD_NONE)
#define CHECK_THRESHOLD(color, threshold)	(color)
#else
#define CHECK_THRESHOLD(color, threshold)	(checkThresholdColorSimple(color, threshold))
#endif

void main ( void )
{
	#if (RENDER_TYPE == MAKE_BLUR)
	{
		vec2 to_center = (uBlurCenter - vTexCoord);
		to_center.x *= uAspect;
		float len = length(to_center);
		to_center = normalize(to_center) * uDeltaTexel;
		to_center *= uBlurPower * len; // 中心に近いほど影響を減らす
		
		gl_FragColor  = texture(uTexture, vTexCoord);
		const float inv_num = 1.0 / SAMPLE_NUM;
		const float inv_num_sqr = inv_num*inv_num;
		for (int i=1; i<SAMPLE_NUM; ++i)
		{
			float dist_damp = (SAMPLE_NUM - i)*(SAMPLE_NUM - i) * inv_num_sqr;
			gl_FragColor += texture(uTexture, vTexCoord + to_center * i) * dist_damp;
		}
		gl_FragColor *= inv_num;
	}
	#elif (RENDER_TYPE == COMPOSE)
	{
		vec3 compose_color = uComposeColor.rgb * uComposeColor.a;
		gl_FragColor  = texture(uTexture,  vTexCoord);
		gl_FragColor.rgb *= compose_color;
	}
	#elif (RENDER_TYPE == MAKE_MASK)
	{
		float depth = texture(uDepth, vTexCoord).r;
		float weight = 1.0;
		
		#if (MODEL_MASK_TYPE == MODEL_MASK_NONE)
		{
			// デプス判定
			#if (MASK_DEPTH_TYPE == MASK_DEPTH_VALUE)
			{
				if (depth < uMaskDepth || depth > uMaskDepthMax) discard;
			}
			#elif (MASK_DEPTH_TYPE == MASK_DEPTH_FAR)
			{
				if (depth != 1.0) discard;
			}
			#endif
		}
		#else // モデルマスクを使う場合は黒を出力したい
		{
			// デプス判定
			#if (MASK_DEPTH_TYPE == MASK_DEPTH_VALUE)
			{
				if (depth < uMaskDepth || depth > uMaskDepthMax) weight = 0.0;
			}
			#elif (MASK_DEPTH_TYPE == MASK_DEPTH_FAR)
			{
				if (depth != 1.0) weight = 0.0;
			}
			#endif
		}
		#endif

		// 距離を使うかどうか
		#if (MASK_DISTANCE_TYPE == MASK_DISTANCE_USE)
		{
			vec2 to_center = (uBlurCenter - vTexCoord);
			to_center.x *= uAspect;
			float length_sqr = dot(to_center, to_center);
			#if (MODEL_MASK_TYPE == MODEL_MASK_NONE)
			{
				if (uMaskRadius < length_sqr) discard;
			}
			#endif // MODEL_MASK_TYPE
			weight *= clamp(1.0 - length_sqr * uInvMaskRadius, 0.0, 1.0);
		}
		#endif // MASK_DISTANCE_USE
		
		gl_FragColor.rgb = CHECK_THRESHOLD(texture(uTexture, vTexCoord).rgb, uThreshold) * weight;
	}
	#endif
}

#endif // AGL_FRAGMENT_SHADER
