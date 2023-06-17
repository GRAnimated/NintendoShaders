/**
 * @file	alLppCausticsLight.glsl
 * @author	Matsuda Hirokazu  (C)Nintendo
 *
 * @brief	ライトプリパスの集光模様ライト
 */

#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable // 明示的な場所指定には必要。無いと GPU ハング。
#endif

#define LPP_TEXTURE_TYPE	(0)
#define LPP_TEXTURE_3D		(0)
#define LPP_TEXTURE_2D		(1)

#define RENDER_TYPE		(0)
#define RENDER_STD		(0)
#define RENDER_NO_NRM	(1)

#define SHADOW_FETCH_TYPE		(0)
#define SHADOW_FETCH_DISABLE	(0)
#define SHADOW_FETCH_ENABLE		(1)

#define FETCH_TYPE							(0)
#define FETCH_TWICE							(0)
#define FETCH_TWICE_CHROMATIC_ABERRATION	(1)
#define FETCH_ONCE							(2)
#define FETCH_ONCE_CHROMATIC_ABERRATION		(3)

#define SHAPE_TYPE							(0)
#define SHAPE_TYPE_CUBE						(0)
#define SHAPE_TYPE_CYLINDER					(1)

#include "agl_lightprepass.shinc"
#include "alMathUtil.glsl"
#include "alLightingFunction.glsl"
#include "alDefineVarying.glsl"
#include "alLppDeclareSampler.glsl"
#include "alGBufferUtil.glsl"
#include "alCalcNormal.glsl"

// 光源の種類で共通
BINDING_SAMPLER_BASECOLOR		uniform sampler2D	uBaseColor;
BINDING_SAMPLER_NORMAL			uniform sampler2D	uNrmMotion;
BINDING_SAMPLER_LINEAR_DEPTH	uniform sampler2D	uViewLinearDepth;
BINDING_SAMPLER_PROJ_TEX		uniform sampler3D 	uCaustics;
BINDING_SAMPLER_DEPTH_SHADOW	uniform sampler2D 	uPrePassShadow;

DECLARE_NOPERS_VARYING(vec2,	vTexCoord);
DECLARE_NOPERS_VARYING(vec3,	vScreen);

/**
 *	ライトプリパスから取得できるUBO型
 */
layout(std140) uniform Context
{
	LPP_UBO_LAYOUT_CONTEXT
};

/**
 *	集光模様ライト
 */
layout(std140) uniform CausticsLightView
{
	vec4		uPVWMtx[4];
	vec4		uInvWorldMtx[3];
	vec4 		uNoiseParam; // xyz : tex crd add,  w : tex crd scale
	vec4		uColorPow;	 // rgb : color, w : color_pow
	vec4		uFetchParam; // xyz : chromatic aberration offset, w : damp pow
	float		uDepthParam; // depth damp pow
};

#define NOISE_TEX_CRD_ADD			uNoiseParam.xyz
#define NOISE_TEX_CRD_SCALE			uNoiseParam.w
#define COLOR_POW					uColorPow.w
#define COLOR 						uColorPow.rgb
#define DAMP_POW					uFetchParam.w
#define CHROMATIC_ABERRATION_OFFSET	uFetchParam.xyz
#define DEPTH_DAMP_POW				uDepthParam

// 必要そうならUniformへ
#define DIST_DAMP_Y_THRESHOLD		0.0075

#define DOT_Y_MIN_INTENSITY			0.25

#define DISCARD_THRESHOLD			0.005

#if defined(AGL_VERTEX_SHADER)
/********************************************************
 *	頂点シェーダ
 */

layout( location = 0 ) in vec3 aPosition;

void main()
{
	gl_Position = multMtx44Vec4(uPVWMtx, vec4(aPosition.xyz, 1.0));
	calcScreenCoord(vScreen, vTexCoord, gl_Position, cLppContext_TanFovyHalf, cLppContext_ProjOffset);
}

#elif defined(AGL_FRAGMENT_SHADER)
/********************************************************
 *	フラグメントシェーダ
 */

out vec4 oColor;

void main()
{
	LightInfo	light;
	InitLightInfo(light);

	FragInfo	frag;
	calcPosV(frag.view_pos
			, uViewLinearDepth
			, getVarying(vScreen)
			, getVarying(vTexCoord)
			, cLppContext_Near
			, cLppContext_Range);
	
	// 範囲外を除外する
	vec3 pos_w = multMtx34Vec3(cLppContext_VMtxInv, frag.view_pos);
	vec3 pos_l = multMtx34Vec3(uInvWorldMtx, pos_w);

	if(pos_l.y > 0.5) discard; //このdiscardは処理対策ではなく、範囲外に絵が出るのを防ぐため
	pos_l.y += 0.5;
	pos_l.y = (1 - pos_l.y) * 0.5;

	float up_dump = clamp01(DIST_DAMP_Y_THRESHOLD - pos_l.y);
	pos_l.y -= up_dump * ((0.5 + DIST_DAMP_Y_THRESHOLD) / DIST_DAMP_Y_THRESHOLD);

#if SHAPE_TYPE == SHAPE_TYPE_CUBE
	vec3 dist_pos_l = pow(abs(pos_l * 2.0), vec3(DAMP_POW));
#elif SHAPE_TYPE == SHAPE_TYPE_CYLINDER
	vec3 dist_pos_l;
	dist_pos_l.y  = pow(abs(pos_l.y * 2.0), DAMP_POW);
	dist_pos_l.x  = pow((pos_l.x * pos_l.x + pos_l.z * pos_l.z) * 4, DAMP_POW); //~0.5～0.5範囲なので、二乗距離で円周の位置は0.25になる。4倍で1にあわせてる。
	dist_pos_l.z = dist_pos_l.x;
#endif
	vec3 dist_dump = clamp01(1.0 - dist_pos_l);

	float intensity = dist_dump.x * dist_dump.y * dist_dump.z;
	vec3 fetch_pos = pos_w * NOISE_TEX_CRD_SCALE;
	vec3 caustics;
	// コースティクス2回フェッチ　進む方向を逆にしてる
	#if (FETCH_TYPE == FETCH_TWICE)
	{
		caustics  = texture(uCaustics, fetch_pos + NOISE_TEX_CRD_ADD).rgb;
		caustics += texture(uCaustics, fetch_pos * 2 - NOISE_TEX_CRD_ADD * 2).rgb;
		caustics *= 0.5 * intensity;
	}
	#elif (FETCH_TYPE == FETCH_TWICE_CHROMATIC_ABERRATION)
	{
		// 1ch のテクスチャから色収差フェッチする
		for (int c=0; c<3; ++c)
		{
			vec3 offset = CHROMATIC_ABERRATION_OFFSET - CHROMATIC_ABERRATION_OFFSET * c;
			caustics[c]  = texture(uCaustics, fetch_pos + NOISE_TEX_CRD_ADD + offset).r;
			caustics[c] += texture(uCaustics, fetch_pos * 2 - NOISE_TEX_CRD_ADD * 2 + offset).r;
		}
		caustics *= 0.5 * intensity;
	}
	#elif (FETCH_TYPE == FETCH_ONCE)
	{
		caustics  = texture(uCaustics, fetch_pos + NOISE_TEX_CRD_ADD).rgb * intensity;
	}
	#elif (FETCH_TYPE == FETCH_ONCE_CHROMATIC_ABERRATION)
	{
		// 1ch のテクスチャから色収差フェッチする
		for (int c=0; c<3; ++c)
		{
			vec3 offset = CHROMATIC_ABERRATION_OFFSET - CHROMATIC_ABERRATION_OFFSET * c;
			caustics[c] = texture(uCaustics, fetch_pos + NOISE_TEX_CRD_ADD + offset).r;
		}
		caustics *= intensity;
	}
	#endif // FETCH_TYPE

	float depth_shadow_factor = 1.0;
	float light_buf_scale = 1.0;
	#if SHADOW_FETCH_TYPE == SHADOW_FETCH_ENABLE
		vec4 shadow_buf = texture(uPrePassShadow,  getVarying(vTexCoord)).rgba;
		depth_shadow_factor = 0.5 + shadow_buf.r * 0.5;
		light_buf_scale = shadow_buf.a;
	#endif
	caustics *= pow(depth_shadow_factor, DEPTH_DAMP_POW);
	caustics = pow(caustics, vec3(COLOR_POW));
	
	// NOTE: GBufferのフェッチが処理を食うのでその前にdiscardすると軽くなる?
	if(length(caustics) < DISCARD_THRESHOLD){
		//discard; 
	}
	
	vec3 bace_color = vec3(1.0);
	
	#if (RENDER_TYPE == RENDER_STD)
		GBufferInfo g_buf;
		// ベースカラー G-Buffer から情報を抽出
		storeFragInfoByBaseColorGBuffer(frag, g_buf, uBaseColor, getVarying(vTexCoord));
		decodeWorldNrm(g_buf, uNrmMotion, getVarying(vTexCoord));
		// Y 軸との内積でコースティクスの強さを制御
		//float dot_y = clamp01((g_buf.normal.y + DOT_Y_ADD) * DOT_Y_MULT);
		float dot_y = g_buf.normal.y;
		float rate  = (dot_y + 1.0) * 0.5;
		caustics *= mix(DOT_Y_MIN_INTENSITY, 1.0, rate * rate);
		bace_color = frag.base_color.rgb;
	#endif

	oColor.rgb = caustics * bace_color * COLOR * light_buf_scale;
}

#endif
