/**
 *	@file	alRenderCloudParticle.glsl
 *	@author	Matsuda Hirokazu  (C)Nintendo
 *
 *	@brief	パーティクルによる雲のレンダリング
 */
 
#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable // 明示的な場所指定には必要。無いと GPU ハング。
#endif

#include "alDeclareUniformBlockBinding.glsl"
#include "alDefineSampler.glsl"
#include "alDeclareSampler.glsl"
#include "alDeclareMdlEnvView.glsl"
#include "alDefineVarying.glsl"
#include "alCloudParticleUtil.glsl"
#include "alPasPhysicalModelParam.glsl"
#include "alETMUtil.glsl"

#define IS_USE_TEXTURE_BIAS		(0)
#include "alHdrUtil.glsl"
#include "alFetchCubeMap.glsl"

#define RENDER_TYPE			(0)
#define RENDER_TEST			(0)
#define RENDER_USING_ETM	(1)

uniform sampler2D uEtmTex;
uniform sampler2D uEtmDistTex;

DECLARE_VARYING(vec4,	vDirLitColor);
DECLARE_VARYING(vec4, 	vDirLitDirWorld);
DECLARE_VARYING(vec4,	vIrradiance);


/**
 *	ETM 変換行列
 */
BINDING_UBO_OTHER_SECOND uniform ETMMtxLightViewUbo
{
	EtmMtx	uEtmMtxLightView;
};

BINDING_UBO_OTHER_THIRD uniform ETMMtxSceneViewUbo
{
	EtmMtx	uEtmMtxSceneView;
};

//------------------------------------------------------------------------------
// 頂点シェーダ
//------------------------------------------------------------------------------
#if defined(AGL_VERTEX_SHADER)

void main()
{
	uint vtx_id = gl_VertexID;
	CloudParticle pt;
	initCloudParticle(pt);
	calcCloudParticleInfo(pt, vtx_id);

	vec3 world_pos = multMtx34Vec3(uWorldMtx, pt.local_pos);

	// キューブマップフェッチ用
	vec3 world_dir = rotMtx34Vec3(uWorldMtx, pt.local_pos);
	{
		// イラディアンス
		vec4 irradiance = vec4(1.0);
		vec3 fetch_dir = world_dir;
		fetchCubeMapIrradianceScaleConvertHdr(getVarying(vIrradiance), cTexCubeMapRoughness, fetch_dir);
	}

	gl_Position = multMtx44Vec3(cViewProj, world_pos);
//	gl_PointSize = pt.size * ScrSizeX / gl_Position.w;
	gl_PointSize = CalcPointSize(pt) * PERS_PARTICLE_SCALE;

	getDirectionalLightColor(getVarying(vDirLitColor), cDirectionalLightColor);

	getVarying(vDirLitDirWorld).xyz = rotMtx33Vec3(cInvView, cDirLightViewDirFetchPos.xyz);
}

//------------------------------------------------------------------------------
// フラグメントシェーダ
//------------------------------------------------------------------------------
#elif defined(AGL_FRAGMENT_SHADER)

layout(location = 0)	out vec4 oColor;

void main()
{
	vec4 clip_pos;
	calcClipPositionFromFragCoord(clip_pos, InvScrSize);
	
	vec4 view_pos = multMtx44Vec4(cInvProj, clip_pos);
	view_pos /= view_pos.w;
	vec3 pos_to_eye_dir = -normalize(view_pos.xyz);
	vec3 lit_to_pos = -cDirLightViewDirFetchPos.xyz;
	vec3 world_pos = multMtx34Vec3(cInvView, view_pos.xyz);

	// Mie 散乱
	float cos_ = dot(lit_to_pos, pos_to_eye_dir);
	#if 0
		float phase = phaseFunctionM(cos_);
	#else
		float phase = calcScatterPhaseFunctionSchlick(CLOUD_KF, CLOUD_KB, CLOUD_KF_KB_MIX, cos_);
	#endif
	float shape; calcCloudParticleCircle(shape, gl_PointCoord);
	if (shape <= 0.0f) discard;
	
	// ETM テクスチャ座標への変換
	#if (RENDER_TYPE == RENDER_USING_ETM)
	{
		vec4 etm_coord = multMtx44Vec3(uEtmMtxLightView.uFetchETMMtx, world_pos);
//		etm_coord.xy /= etm_coord.w;
		// 奥行きの範囲を取得
		vec2 start_end;
		getTraversalStartEnd(start_end, etm_coord.xy, uEtmDistTex);
		// DCT 係数を取得
		vec4 dct_coef = texture(uEtmTex, etm_coord.xy);

		float T, x = etm_coord.z, d_max = start_end.y; // etm_coord.z も [-1, 1] -> [0, 1] になっているっぽい。参照：ShadowMatrixUpdator
		x = x*DIST_SCALE + CAM_TO_NEAR_DIST; d_max *= DIST_SCALE;
		calcTransmittanceByEtm4(T, dct_coef, x, d_max, TRANSMITTANCE_EXP_SCALE, uDctWeight);
		float powder = clamp01(1.0 - pow(clamp01(1.0 - etm_coord.z), 4));
//		phase *= powder*0.5;
		
		oColor = vec4(0);
	//	oColor.a = shape;
		oColor.a = 1.0;
	//	oColor.xyz = vec3(lit_to_pos.x);
	//	oColor.xyz = vec3(clip_pos.w);
	//	oColor.xyz = vec3(pos_to_eye_dir.x);
	//	oColor.xyz = vec3(shape);
	//	oColor.xyz = vec3(clamp01(T));
	//	oColor.xyz = vec3(etm_coord.x);
	//	oColor.xyz = vec3((gl_FragCoord.xy * InvScrSize).x);
	//	oColor.xyz = vec3(gl_FragCoord.w);
	//	oColor.xyz = vec3(gl_FragCoord.z * gl_FragCoord.w);
	//	oColor.xyz = vec3(gl_FragCoord.z / gl_FragCoord.w);
		oColor.xyz = vec3(getVarying(vDirLitColor).rgb * phase * T + getVarying(vIrradiance).rgb);
	//	oColor = vec4(dct_coef.xyz, phase);
	//	oColor.rg = etm_coord.xy;
	}
	#else
	{
		oColor = vec4(getVarying(vDirLitColor).rgb * phase + getVarying(vIrradiance).rgb, shape);
	}
	#endif // RENDER_TYPE
}

#endif // AGL_FRAGMENT_SHADER
