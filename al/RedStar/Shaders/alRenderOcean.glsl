/**
 * @file	alRenderOceanMeshDebug.glsl
 * @author	Matsuda Hirokazu  (C)Nintendo
 *
 * @brief	
 */

#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable // 明示的な場所指定には必要。無いと GPU ハング。
#endif


#include "alDeclareUniformBlockBinding.glsl"
#include "alCalcNormal.glsl"
#include "alMathUtil.glsl"
#include "alDeclareMdlEnvView.glsl"	// 環境と視点を合わせたデータ 
#include "alDefineSampler.glsl"
#include "alDefineVarying.glsl"

#include "alCalcLighting.glsl"
#include "alWrapLightingFunction.glsl"
#define IS_USE_TEXTURE_BIAS		(0)
#include "alHdrUtil.glsl"
#include "alFetchCubeMap.glsl"

#include "alEnvBrdfUtil.glsl"
#include "alCalcIndirect.glsl"
#include "alGBufferUtil.glsl"

#define DISP_TYPE			(0) // @@ id="cDispType" choice="0,1" default="0"
#define DISP_TYPE_OCEAN			(0)
#define DISP_TYPE_RIPPLE_OCEAN	(1)

#define RIPPLE_CLAMP_TYPE		(0) // @@ id="cRippleClampType" choice="0,1" default="0"
#define RIPPLE_CLAMP_DISABLE	(0)
#define RIPPLE_CLAMP_ENABLE		(1)

#define RENDER_TYPE			(0)
#define TYPE_FORWARD		(0)
#define TYPE_DEFERRED_OPA	(1)
#define TYPE_DEFERRED_XLU	(2)
#define TYPE_Z_ONLY			(3)

#define MATERIAL_TYPE	(0)
#define TYPE_OCEAN		(0)
#define TYPE_CLOUD		(1)

#define NRM_FETCH_TYPE	(1) // @@ id="cNrmFetchType" choice="0,1" default="0"
#define NRM_FETCH_FS	(0)
#define NRM_FETCH_FS_2	(1)

#define TRANSLUCENT_TYPE	(1) // @@ id="cTranslucentType" choice="0,1,2" default="1"
#define TYPE_NONE			(0)
#define TYPE_INDIRECT		(1)
#define TYPE_XLU			(2)

#define DEPTH_FETCH_TYPE	(0) // @@ id="cDepthFetchType" choice="0,1,2" default="0"
#define DEPTH_FETCH_DISABLE	(0)
#define DEPTH_FETCH_ENABLE	(1)
#define HEIGHT_TEX_ENABLE	(2)

#define FAR_FLAT_TYPE		(0) // @@ id="cFarFlatType" choice="0,1" default="0"
#define FAR_FLAT_DISABLE	(0)
#define FAR_FLAT_ENABLE		(1)

#define LINEAR_DEPTH_OPA_TYPE		(0) // @@ id="cLinearDepthOpaType" choice="0,1" default="0"
#define LINEAR_DEPTH_OPA_DISABLE	(0)
#define LINEAR_DEPTH_OPA_ENABLE		(1)

#define FORWARD_GGX_SPECULAR_TYPE		(0) // @@ id="cGgxSpecularType" choice="0,1" default="0"
#define FORWARD_GGX_SPECULAR_DISABLE	(0)
#define FORWARD_GGX_SPECULAR_ENABLE		(1)

#define SHORE_TYPE		(0) // @@ id="cShoreParamType" choice="0,1" default="0"
#define SHORE_DISABLE	(0)
#define SHORE_ENABLE		(1)

#define TEST_PARAM_TYPE			(0) // @@ id="cTestParamType" choice="0,1" default="0"
#define TEST_PARAM_DISABLE		(0)
#define TEST_PARAM_ENABLE		(1)

#define RIPPLE_ALPHA_TYPE		(1)// @@ id="cRippleAlphaType", choice="0,1" default="1"
#define RIPPLE_ALPHA_DISABLE	(0)
#define RIPPLE_ALPHA_ENABLE		(1)

#define NOISE_TEX_TYPE			(0)// @@ id="cNoiseType", choice="0,1", default="0"
#define NOISE_TEX_DISABLE		(0)
#define NOISE_TEX_ENABLE		(1)

#define SHADOW_TYPE				(0)// @@ id="cShadowType", choice="0,1", default="0"
#define SHADOW_DISABLE			(0)
#define SHADOW_ENABLE			(1)

#define AO_SHADOW_TYPE				(0)// @@ id="cAoShadowType", choice="0,1", default="0"
#define AO_SHADOW_DISABLE			(0)
#define AO_SHADOW_ENABLE			(1)

#define SPHERE_CURVE_TYPE			(0)// @@ id="cSphereCurveType", choice="0,1", default="0"
#define SPHERE_CURVE_DISABLE		(0)
#define SPHERE_CURVE_ENABLE			(1)

// Varying 定義
DECLARE_VARYING(vec3,	vPosView);
DECLARE_VARYING(vec4,	vNormalWorldDepthView);	
DECLARE_NOPERS_VARYING(vec4,	vPosProj);// インダイレクト、鏡用（zw は鏡用）
DECLARE_VARYING(vec4,	vDirLitColor);
DECLARE_VARYING(vec4,	vDepthParam); // 上からの撮影デプスによるパラメータ
DECLARE_VARYING(vec4,	vFarParam); // 距離
DECLARE_VARYING(vec4,	vDisplacement);	//　ディスプレイスメント変動量
DECLARE_VARYING(vec2,	vScreen);

#if (NRM_FETCH_TYPE == NRM_FETCH_FS || NRM_FETCH_TYPE == NRM_FETCH_FS_2)
	DECLARE_VARYING(vec3,	vNormal);
	DECLARE_VARYING(vec3,	vBinormal);
	DECLARE_VARYING(vec3,	vTangent);
	DECLARE_VARYING(vec2,	vTexCoord); 
	
#endif // NRM_FETCH_TYPE

#if (DISP_TYPE == DISP_TYPE_RIPPLE_OCEAN)
	DECLARE_VARYING(vec4,	vTexCoordRipple);
#endif

#if (SHORE_TYPE == SHORE_ENABLE)
	DECLARE_VARYING(vec4,	vShoreParam); 
#endif

BINDING_UBO_OTHER_FIRST uniform NodeParam
{
	vec4	uWorldMtx[3];
	vec4	uDispData; // x: disp scale, y: texel len x2, zw: disp tex crd scale
};

BINDING_UBO_OTHER_SECOND uniform SceneMtx
{
	vec4	uViewProj[4];
};

BINDING_UBO_OTHER_THIRD uniform OceanParam
{
	vec4 uMat;  // x : Refract Eta, y : Refract Rate, z : Roughness, w : metalness
	vec4 uMat2; // x : Scatter Scale, y : Phase K, z : Phase Back K, w : Phase Rate
	vec4 uMat3; // x : F0, y : High Frequency Normal UV Scale, z : High Frequency Normal Scale, w : depth scale
	vec4 uBaseColor;
	vec4 uRefractColor;
	vec4 uRippleParam;
	vec4 uRippleParam2;
	
	vec4 uDepthViewProj[4];
	vec4 uDepthParam; // x: camera_pos_y, y: camera_far z:depth_rate_min

	vec4 uShoreParam;  //x:depth_grad_scale y:ripple_grad_scale z:color_scale

	vec4 uHeightViewProj[4];
	vec4 uHeightParam; // x: height_check_dist

	vec4 uFarParam;   // xy: far_flat_distance near/far  wz:far_flat_distance(normal) near/far
	vec4 uFarParam2;  // xy: far_flat_distance(high nrm) z: far_nrm_min_rate, w: far_roughness
	vec4 uLinearDepthParam;   // x:scale y:start
	vec4 uColorDamp;
	vec4 uCloudParam;	// x: バックライトの強度　y: 透けさせる距離 z:波紋による横移動スケール w:波紋によるアルファ０高さ

	vec4 uNoiseParam; // xyz : tex crd add,  w : tex crd scale
	vec4 uNoiseScale; 

	vec4 uBubbleParam1;
	vec4 uBubbleParam2;
	vec4 uBubbleColor;

	vec4 uAoDepthViewProj[4];
	vec4 uAoShadowColor;

	vec4 uSphereCurveParam0;
	vec4 uSphereCurveParam1;
};
 
// DeclareSampler.glslから必要なものだけコピー
BINDING_SAMPLER_DIR_LIT_COLOR			uniform sampler2D cDirectionalLightColor;
BINDING_SAMPLER_NORMAL					uniform sampler2D cTextureNormal;
BINDING_SAMPLER_ENV_CUBE_MAP_ROUGHNESS	uniform samplerCube cTexCubeMapRoughness;
BINDING_SAMPLER_DEPTH					uniform sampler2D cTextureLinearDepth;
BINDING_SAMPLER_TEMPORARY				uniform sampler2D cFrameBufferTex;
BINDING_SAMPLER_MATERIAL_LIGHT_CUBE		uniform samplerCube cTextureMaterialLightCube;
BINDING_SAMPLER_BASE_COLOR				uniform sampler2D cTextureBaseColor;

#if DISP_TYPE == DISP_TYPE_RIPPLE_OCEAN
	uniform sampler2D cTextureRippleHeight;
	uniform sampler2D cTextureRippleGradient;
#endif

uniform sampler2D cTextureDisplacement;

#if SHORE_TYPE == SHORE_ENABLE
	uniform sampler2D cTextureDepthGradMap;
	uniform sampler2D cTextureDepthShoreMap;
#endif

#if DEPTH_FETCH_TYPE == HEIGHT_TEX_ENABLE
	uniform sampler2D cTextureDepthHeightMap;
	uniform sampler2D cTextureDepthHeightGradMap;
#elif DEPTH_FETCH_TYPE == DEPTH_FETCH_ENABLE
	uniform sampler2D cTextureDepthMap;
#endif

#if SHADOW_TYPE == SHADOW_ENABLE
	uniform sampler2D cPrePassShadow;
#endif

#if AO_SHADOW_TYPE == AO_SHADOW_ENABLE
	uniform sampler2D cTextureAoDepthMap;
#endif

#if (NOISE_TEX_TYPE == NOISE_TEX_ENABLE)
	uniform sampler3D cNoise3D;
#endif

#define DISP_SCALE			uDispData.x
#define DISP_TEXEL_LEN_X2	uDispData.y
#define DISP_TEX_CRD_SCALE	uDispData.zw

#define RIPPLE_CENTER_POS	uRippleParam.xy
#define RIPPLE_TEX_SCALE	uRippleParam.z
#define RIPPLE_SCALE		uRippleParam.w

#define RIPPLE_NORMAL_SCALE		uRippleParam2.x
#define RIPPLE_HEIGHT_CLAMP		uRippleParam2.y

#define REFRACT_ETA			uMat.x
#define REFRACT_RATE		uMat.y
#define ROUGHNESS			uMat.z
#define METALNESS			uMat.w
#define SCATTER_SCALE		uMat2.x
#define PHASE_K				uMat2.y
#define PHASE_BACK_K		uMat2.z
#define PHASE_RATE			uMat2.w
#define FRESNEL_0			uMat3.x
#define HIGH_NRM_UV_SCALE	uMat3.y
#define HIGH_NRM_SCALE		uMat3.z
#define DEPTH_SCALE			uMat3.w
#define BASE_COLOR			uBaseColor.rgb
#define REFRACT_COLOR		uRefractColor.rgb
#define COLOR_DAMP			uColorDamp.rgb

#define DEPTH_CAMERA_HEIGHT uDepthParam.x
#define DEPTH_CAMERA_FAR	uDepthParam.y

#define FLAT_DISTANCE_NEAR	uFarParam.x
#define FLAT_DISTANCE_FAR	uFarParam.y
#define FLAT_DISTANCE_NEAR_NRM	uFarParam.z
#define FLAT_DISTANCE_FAR_NRM	uFarParam.w
#define FLAT_DISTANCE_NEAR_HIGH_NRM	uFarParam2.x
#define FLAT_DISTANCE_FAR_HIGH_NRM	uFarParam2.y
#define FLAT_NRM_MIN_RATE		uFarParam2.z
#define FAR_ROUGHNESS		uFarParam2.w
#define FAR_REFRACT_RATE	uLinearDepthParam.z
#define	OPA_DISTANCE_NEAR	uFarParam.z
#define OPA_DISTANCE_FAR	uFarParam.w

#define LINEAR_DAMP_SCALE	uLinearDepthParam.x
#define LINEAR_DAMP_START	uLinearDepthParam.y

#define HEIGHT_CHECK_DIST 	uHeightParam.x

#define CLOUD_BACKLIGHT_POWER	uCloudParam.x
#define CLOUD_ALPHA_DAMP_DIST	uCloudParam.y
#define CLOUD_RIPPLE_XZ_MOVE_SCALE	uCloudParam.z
#define CLOUD_RIPPLE_ALPHA_ZERO_HEIGHT uCloudParam.w

#define NOISE_TEX_CRD_ADD		uNoiseParam.xyz
#define NOISE_TEX_CRD_SCALE		uNoiseParam.w
#define NOISE_INTENSITY			uNoiseScale.x
#define NOISE_DIST_COEF			uNoiseScale.y

#define SPHERE_CURVE_TONE_POW	uSphereCurveParam0.x
#define SPHERE_CURVE_SLOPE		uSphereCurveParam0.y
#define SPHERE_CURVE_PEAK_POS	uSphereCurveParam0.z
#define SPHERE_CURVE_PEAK_POW	uSphereCurveParam0.w
#define SPHERE_CURVE_PEAK_INTENSITY	uSphereCurveParam1.x
#define SPHERE_CURVE_FRONT_K			uSphereCurveParam1.y
#define SPHERE_CURVE_BACK_K				uSphereCurveParam1.z
#define SPHERE_CURVE_FRONT_BACK_RATE	uSphereCurveParam1.w

//------------------------------------------------------------------------------
// 頂点シェーダ
//------------------------------------------------------------------------------
#if defined(AGL_VERTEX_SHADER)
precision mediump float;

layout (location=0) in vec2 aPositionXZ;	// @@ id="_p0" hint="position0"

void main()
{
	float depth_rate = 1.0; // 上から撮影のデプスによる減衰レート
	float far_rate = 1.0;   // 距離による減衰レート
	vec3 world = multMtx34Vec3(uWorldMtx, vec3(aPositionXZ.x, 0, aPositionXZ.y));
	vec3 view = multMtx34Vec3(cView, world);
	vec2 grad = vec2(0.0);
	vec2 depth_tcrd;
	float pos_y = 0.0;

	// 上から撮影したデプスによる高さ制限
	#if ( DEPTH_FETCH_TYPE == DEPTH_FETCH_ENABLE )
		depth_tcrd = multMtx44Vec4(uDepthViewProj, vec4(world, 1.0)).xy;
		float dr = texture(cTextureDepthMap, depth_tcrd).r;
		depth_rate = max(dr * dr, uDepthParam.z);
		getVarying(vDepthParam).x = dr;
	#endif

	// 距離による高さ制限
	#if (FAR_FLAT_TYPE == FAR_FLAT_ENABLE)
	{	
		float dist = distance(cCameraPos.xz, world.xz); // sqrt((cCameraPos.x - world.x) * (cCameraPos.x - world.x) + (cCameraPos.z - world.z) * (cCameraPos.z - world.z));
		far_rate = clamp01(1.0 + (-dist + FLAT_DISTANCE_NEAR) / (FLAT_DISTANCE_FAR - FLAT_DISTANCE_NEAR));
		getVarying(vFarParam).x = clamp01(1.0 + (-dist + FLAT_DISTANCE_NEAR_NRM) / (FLAT_DISTANCE_FAR_NRM - FLAT_DISTANCE_NEAR_NRM));
		getVarying(vFarParam).z = clamp01(1.0 + (-dist + FLAT_DISTANCE_NEAR_HIGH_NRM) / (FLAT_DISTANCE_FAR_HIGH_NRM - FLAT_DISTANCE_NEAR_HIGH_NRM));
		//getVarying(vFarParam).y = clamp01((dist - 250000) * 0.000001); // 遠くのアルファ抜き用
	}
	#endif

	// デプスと距離の高さ制限の積が実際の制限になる
	float rate = depth_rate * far_rate;

	// ディスプレースメント計算
	vec2 disp_tcrd = aPositionXZ * DISP_TEX_CRD_SCALE; // PositionXZ == TexCoord
	vec3 displacement = texture(cTextureDisplacement, disp_tcrd).rgb;// + texture(cTextureDisplacement, disp_tcrd*2).rgb;
	vec3 disp_pos = vec3(0.0);
	// 横方向の移動はdepthによって抑制しない。浅瀬は横移動をます
	vec3 disp   = displacement * far_rate * DISP_SCALE * (-depth_rate * 0.3 + 1.3);
	disp_pos.xz = aPositionXZ + disp.xz;
	disp.y     = displacement.y * rate * DISP_SCALE;
	disp_pos.y  = pos_y + disp.y;
	getVarying(vDisplacement).xyz = disp;
	vec3 w_pos	= multMtx34Vec3(uWorldMtx, disp_pos);

	#if (DISP_TYPE == DISP_TYPE_RIPPLE_OCEAN)
	{
		// 波紋による頂点変動を反映
		vec2 sim_uv = w_pos.xz - RIPPLE_CENTER_POS;
		sim_uv.x    = sim_uv.x * RIPPLE_TEX_SCALE;
		sim_uv.y    = sim_uv.y * RIPPLE_TEX_SCALE;
		vec4 ripple_tex     = texture(cTextureRippleHeight, sim_uv);
		float ripple_height = ripple_tex.r * RIPPLE_SCALE * rate;
		#if RIPPLE_CLAMP_TYPE == RIPPLE_CLAMP_ENABLE
			ripple_height = clamp(ripple_height, -RIPPLE_HEIGHT_CLAMP, RIPPLE_HEIGHT_CLAMP);
		#endif
		w_pos.y += ripple_height; 
		getVarying(vTexCoordRipple).xy	= sim_uv;
		getVarying(vTexCoordRipple).z   = ripple_height;
	}
	#endif // DISP_TYPE

	#if (DEPTH_FETCH_TYPE == HEIGHT_TEX_ENABLE)
		// ベースの高さを一定ではなくテクスチャでかえる
		vec2 height_tcrd = multMtx44Vec4(uHeightViewProj, vec4(w_pos, 1.0)).xy;
		float height_val = (texture(cTextureDepthHeightMap, height_tcrd).r - 0.5);
		getVarying(vDepthParam).w  = height_val;
		w_pos.y -= height_val * HEIGHT_CHECK_DIST; // 0.5なら同じ高さ、それ以上なら低い
	#endif

	gl_Position	= multMtx44Vec3(uViewProj, w_pos);

	#if (NRM_FETCH_TYPE == NRM_FETCH_FS || NRM_FETCH_TYPE == NRM_FETCH_FS_2)
	{
		getVarying(vNormal)			= normalize(rotMtx34Vec3(uWorldMtx, vec3(0, 1, 0)));
		getVarying(vTangent)		= normalize(rotMtx34Vec3(uWorldMtx, vec3(0, 0, 1)));
		getVarying(vBinormal).xyz	= cross(vNormal.xyz, vTangent.xyz);
		getVarying(vTexCoord)		= aPositionXZ * DISP_TEX_CRD_SCALE;
	}
	#endif // NRM_FETCH_TYPE
	
	getVarying(vPosView)  = multMtx34Vec3(cView, w_pos);

	// インダイレクト
	#if (TRANSLUCENT_TYPE == TYPE_INDIRECT)
	{
		getVarying(vPosProj).xy = gl_Position.xy/gl_Position.w;
	}
	#endif // 

	#if (RENDER_TYPE == TYPE_DEFERRED_OPA)
	{
		calcNormalizedLinearViewDepth(cViewProj, gl_Position, cNear, cInvRange);
	}
	#endif

	#if (DEPTH_FETCH_TYPE == DEPTH_FETCH_ENABLE && SHORE_TYPE == SHORE_ENABLE)
	{
		// disp反映後/反映前の結果の間を使う
		float disp_rate = 0;
		vec2 depth_tcrd_disp = multMtx44Vec4(uDepthViewProj, vec4(w_pos, 1.0)).xy;
		getVarying(vShoreParam).xy = depth_tcrd_disp * disp_rate + depth_tcrd * (1.0 - disp_rate);
		getVarying(vShoreParam).zw = disp.xz;
	}
	#endif
	// ディレクショナルライトのカラー
	getVarying(vDirLitColor) = texture(cDirectionalLightColor, vec2(cDirLightViewDirFetchPos.w, 0.5));
	gl_PointSize = 10.0;

	getVarying(vScreen).xy = gl_Position.xy / gl_Position.w;
#if defined( AGL_TARGET_GX2 ) || defined( AGL_TARGET_NVN )
	getVarying(vScreen).y *= -1.0;
#endif
	getVarying(vScreen).xy *= -cTanFovyHalf.xy;
	getVarying(vScreen).xy -= cScrProjOffset.xy;
}

//------------------------------------------------------------------------------
// フラグメントシェーダ
//------------------------------------------------------------------------------
#elif defined(AGL_FRAGMENT_SHADER)

#include "alLightingFunction.glsl"
#include "alDeclareGBuffer.glsl"
precision mediump float;
void main ( void )
{
#if RENDER_TYPE == TYPE_Z_ONLY
#if (DEPTH_FETCH_TYPE == HEIGHT_TEX_ENABLE)
	if(getVarying(vDepthParam).w < uHeightParam.y) discard;
#endif
	oBaseColor	= vec4(1.0);
#else
	vec3 nrm;
	vec4 grad_1;
	vec4 grad_2;
	vec4 ripple_grad;
	float depth = 1.0;
	float depth_view_diff = 0.0;
	float in_water_distance = 0.0;
	float metalness = METALNESS;
	float bubble_power = 0.0;
//	float bubble_power = clamp01(abs(getVarying(vTexCoordRipple).z * uBubbleParam1.x)); 
//	bubble_power *= bubble_power;
	
	vec2 ripple_grad_val;

	#if SHORE_TYPE == SHORE_ENABLE
	vec4 shore_val;
	#endif

	// 法線マップ適用　ディスプレイスメント＋波紋
	#if (NRM_FETCH_TYPE == NRM_FETCH_FS)
	{
		vec4 grad	= texture(cTextureNormal, getVarying(vTexCoord));

		#if (DISP_TYPE == DISP_TYPE_RIPPLE_OCEAN)
		{
			ripple_grad	= texture(cTextureRippleGradient, getVarying(vTexCoordRipple).xy);	
			ripple_grad_val = ripple_grad.xy * RIPPLE_NORMAL_SCALE;
			grad.xy += ripple_grad_val;
		}
		#endif
		nrm	= getVarying(vNormal).xyz * DISP_TEXEL_LEN_X2 + getVarying(vBinormal).xyz * grad.x + getVarying(vTangent).xyz * grad.y;
		nrm.xyz	= normalize(nrm);
	}
	#elif (NRM_FETCH_TYPE == NRM_FETCH_FS_2)
	{
		//NOTE 2回フェッチ結構重い
		grad_1	= texture(cTextureNormal, getVarying(vTexCoord));
		//#if TEST_PARAM_TYPE == TEST_PARAM_ENABLE
		#if (FAR_FLAT_TYPE == FAR_FLAT_ENABLE)
			vec2 g = vec2(0.0);
			if(getVarying(vFarParam).z > 0.001){
				grad_2	= texture(cTextureNormal, getVarying(vTexCoord)*HIGH_NRM_UV_SCALE);
				g = grad_2.xy * (getVarying(vFarParam).z * getVarying(vFarParam).z);
			}
			vec2 grad	= g * HIGH_NRM_SCALE + grad_1.xy;
		#else
			grad_2	= texture(cTextureNormal, getVarying(vTexCoord)*HIGH_NRM_UV_SCALE);
			vec2 grad	= grad_1.xy + grad_2.xy * HIGH_NRM_SCALE;	
		#endif

		// #else
		// 	vec2 g = vec2(0.0);
		// 	grad_2	= texture(cTextureNormal, getVarying(vTexCoord)*HIGH_NRM_UV_SCALE);
		// 	g = grad_2.xy * getVarying(vFarParam).z;
		// 	vec2 grad	= g * HIGH_NRM_SCALE + grad_1.xy;
		// #endif

		#if (DISP_TYPE == DISP_TYPE_RIPPLE_OCEAN)
		{
			ripple_grad	= texture(cTextureRippleGradient, getVarying(vTexCoordRipple).xy);
			ripple_grad_val = ripple_grad.xy * RIPPLE_NORMAL_SCALE;
			grad += ripple_grad_val;

			bubble_power = ripple_grad.x * ripple_grad.x + ripple_grad.y * ripple_grad.y;
			bubble_power *= uBubbleParam1.x;
			bubble_power = clamp01(bubble_power);
		}
		#endif

		nrm	= getVarying(vNormal).xyz * DISP_TEXEL_LEN_X2 + getVarying(vBinormal).xyz * grad.x + getVarying(vTangent).xyz * grad.y;
		nrm.xyz	= normalize(nrm);
	}
	#endif // NRM_FETCH_TYPE


	// 遠くを平坦にする場合、法線を010に寄せていく
	#if (FAR_FLAT_TYPE == FAR_FLAT_ENABLE)
	{
		// 高さマップを使ってる場合、そこからもとめた法線によせていく
		#if DEPTH_FETCH_TYPE == HEIGHT_TEX_ENABLE
			vec4 height_grad	= texture(cTextureDepthHeightGradMap, getVarying(vTexCoord));
			vec3 height_nrm		= normalize(getVarying(vNormal).xyz * DISP_TEXEL_LEN_X2 + getVarying(vBinormal).xyz * height_grad.x + getVarying(vTangent).xyz * height_grad.y);
			nrm.xyz = mix(height_nrm, nrm.xyz, clamp01(getVarying(vFarParam).x* getVarying(vFarParam).x + FLAT_NRM_MIN_RATE)); 
		#else
		// 高さマップを使っていない場合、010によせていく
			nrm.xyz = mix(vec3(0.0, 1.0, 0.0), nrm.xyz, clamp01(getVarying(vFarParam).x * getVarying(vFarParam).x + FLAT_NRM_MIN_RATE)); //+0.15は最小でもわずかに残すため
		#endif
	}
	#endif
	
	// 裏の場合法線反転
	nrm = gl_FrontFacing ? nrm : -nrm;
	
	// ビュー空間法線
	vec3 pos_to_eye		= -normalize(getVarying(vPosView));
	vec3 view_nrm		= normalize(rotMtx33Vec3(cView, nrm));
	vec3 ray_reflect_v	= reflect(-pos_to_eye, view_nrm);
	vec3 ray_reflect_w	= rotMtx33Vec3(cInvView, ray_reflect_v);
	float N_V			= clamp01(dot3(view_nrm, pos_to_eye)); // 屈折とモデルスペキュラ、フレネルで使う
	vec3 dir_light_color= getVarying(vDirLitColor).rgb;
	
	float blend_alpha = 1;
	vec3 light_buf_color = vec3(0.0);

	#if (MATERIAL_TYPE == TYPE_CLOUD)
	{
	
		vec2 uv = (getVarying(vPosProj).xy + 1.0) * 0.5;
		uv.y = 1.0 - uv.y;

		// デプス差分を計算
		#if (LINEAR_DEPTH_OPA_TYPE == LINEAR_DEPTH_OPA_ENABLE)
			depth = texture(cTextureLinearDepth, uv).r;
			// 海面位置とデプス位置の差
			depth_view_diff = ( depth * cRange + cNear ) + getVarying(vPosView).z;

			blend_alpha *= clamp01(depth_view_diff / CLOUD_ALPHA_DAMP_DIST );
		#endif

		float depth_shadow_factor = 1.0;
		float light_buf_scale = 1.0;
		#if SHADOW_TYPE == SHADOW_ENABLE
			//	vec2 screen_coord = getVarying(vTexCoord);
			vec4 shadow_buf = texture(cPrePassShadow, uv).rgba;
			depth_shadow_factor = 0.5 + shadow_buf.r * 0.5;
			light_buf_scale = shadow_buf.a;
			#if (DEPTH_FETCH_TYPE == HEIGHT_TEX_ENABLE)
				// 帽子W用の怪しすぎる処理
				if(getVarying(vDepthParam).w < uHeightParam.y){
					depth_shadow_factor = mix(depth_shadow_factor, 1.0, blend_alpha);
					light_buf_scale     = mix(light_buf_scale, 1.0, blend_alpha);
				}
			#endif
		#endif

		// ディフューズ
		float diffuse = calcWrapLighting(dot(view_nrm, cDirLightViewDirFetchPos.xyz), 1);
		float diffuse_back = calcWrapLighting(dot(view_nrm, -cDirLightViewDirFetchPos.xyz), 1);
		diffuse += diffuse_back * CLOUD_BACKLIGHT_POWER;
		light_buf_color += diffuse * BASE_COLOR * dir_light_color * depth_shadow_factor;


		#if (NOISE_TEX_TYPE == NOISE_TEX_ENABLE)
		{
			vec3 viewpos = getVarying(vPosView);
			vec3 pos_w = multMtx34Vec3(cInvView, viewpos);
			float noise = texture(cNoise3D, pos_w * NOISE_TEX_CRD_SCALE + NOISE_TEX_CRD_ADD).r;
			noise *= clamp01(1 - clamp01(-viewpos.z / 30000.0) - blend_alpha) * 0.7;
			blend_alpha = clamp01(blend_alpha - noise);
			//light_buf_color.rgb += noise * 20.0; 
		}
		#endif

		#if (DISP_TYPE == DISP_TYPE_RIPPLE_OCEAN)
		{
			#if (RIPPLE_ALPHA_TYPE == RIPPLE_ALPHA_ENABLE)
				blend_alpha *= clamp01(1 - abs(getVarying(vTexCoordRipple).z) / CLOUD_RIPPLE_ALPHA_ZERO_HEIGHT);
			#else
				light_buf_color -= 0.5 * light_buf_color * clamp01(abs(getVarying(vTexCoordRipple).z) / CLOUD_RIPPLE_ALPHA_ZERO_HEIGHT);
			#endif
		}
		#endif
	
		// イラディアンス
		// フラグメント毎にイラディアンスを引っぱってくる
		vec4 irradiance = vec4(1.0);
		vec3 fetch_dir = nrm;
		fetchCubeMapIrradianceScaleConvertHdr(irradiance, cTextureMaterialLightCube, fetch_dir);

		// スフィアカーブ	
		#if SPHERE_CURVE_TYPE == SPHERE_CURVE_ENABLE
			float tone = pow(N_V, SPHERE_CURVE_TONE_POW)*SPHERE_CURVE_SLOPE;
			float peak_pos = N_V - SPHERE_CURVE_PEAK_POS;
			float peak = exp2(-peak_pos*peak_pos*100.0*SPHERE_CURVE_PEAK_POW)*SPHERE_CURVE_PEAK_INTENSITY;
			float sphere_value = clamp01(tone + peak);

			light_buf_color += getVarying(dir_light_color).rgb * (sphere_value * 
				calcScatterPhaseFunctionSchlick(SPHERE_CURVE_FRONT_K,SPHERE_CURVE_BACK_K,SPHERE_CURVE_FRONT_BACK_RATE, dot(pos_to_eye, -cDirLightViewDirFetchPos.xyz))); 
		#endif

		light_buf_color += BASE_COLOR * irradiance.rgb;
		light_buf_color *= light_buf_scale;

		//light_buf_color = vec3(0);
		//light_buf_color.r += phase * 40;
	}
	#elif (MATERIAL_TYPE == TYPE_OCEAN)
	{
		float refractness = REFRACT_RATE; // 屈折率
		vec3 base_color = BASE_COLOR;
		float roughness = ROUGHNESS;
		vec2 uv;
		vec3 view_diff;
		// インダイレクト後のデプスをとる
		#if (TRANSLUCENT_TYPE == TYPE_INDIRECT)
		{
			view_diff = REFRACT_ETA * -N_V * view_nrm; 
			uv = getVarying(vPosProj).xy + view_diff.xy;
			toScreenUv(uv);
			float indirect_depth = texture(cTextureLinearDepth, uv).r;
			float indirect_depth_view_diff = (indirect_depth * cRange + cNear ) + getVarying(vPosView).z;
			if(indirect_depth_view_diff < 0){
				uv = getVarying(vPosProj).xy;
			}else{	
				float indirect_rate = clamp01(indirect_depth_view_diff * 0.001);
				indirect_rate *= indirect_rate;
				view_diff *= indirect_rate;							
				uv = getVarying(vPosProj).xy + view_diff.xy;										
			}
			toScreenUv(uv);
			depth = texture(cTextureLinearDepth, uv).r;
			depth_view_diff = (depth * cRange + cNear ) + getVarying(vPosView).z;
		}
		#endif
		float bubble_power_depth = 0.0;
		// デプス差分を計算
		#if (LINEAR_DEPTH_OPA_TYPE == LINEAR_DEPTH_OPA_ENABLE)
			// インダイレクトの場合は計算済
			#if (TRANSLUCENT_TYPE != TYPE_INDIRECT)
				uv = (getVarying(vPosProj).xy + 1.0) * 0.5;
				uv.y = 1.0 - uv.y;
				depth = texture(cTextureLinearDepth, uv).r;
				// 海面位置とデプス位置の差
				depth_view_diff  = (depth * cRange + cNear ) + getVarying(vPosView).z;
			#endif

			in_water_distance =  gl_FrontFacing ? depth_view_diff : -getVarying(vPosView).z;
			blend_alpha *= clamp01(in_water_distance / 80.0 );
			#if (NOISE_TEX_TYPE == NOISE_TEX_ENABLE)
			{
				float d_rate = clamp01((60 - depth_view_diff) / 60.0);
				bubble_power_depth = clamp01(d_rate*d_rate);
			}
			#endif
		#endif

		#if (FAR_FLAT_TYPE == FAR_FLAT_ENABLE)
		{
			float ref_rate = (1-getVarying(vFarParam).x * getVarying(vFarParam).x)* clamp01(depth_view_diff / 300);
			refractness = mix(refractness, FAR_REFRACT_RATE, ref_rate);
			metalness   = mix(metalness, 1-FAR_REFRACT_RATE, ref_rate); // めっちゃ怪しい
			roughness   = mix(roughness, FAR_ROUGHNESS, 1-getVarying(vFarParam).x);
			
		}
		#endif
		float shore_power = 0.0;
		// 浜辺処理　傾きテクスチャを参照して、泡をいれてく
#if SHORE_TYPE == SHORE_ENABLE
		vec2 shore_grad =  texture(cTextureDepthGradMap, getVarying(vShoreParam).xy).rg;
		float shore_depth = texture(cTextureDepthShoreMap, getVarying(vShoreParam).xy).r;
		// 傾きが0でない場所のデプスで、パワーを決定する
		//float shore_power = clamp01((abs(grad.x)+abs(grad.y))*100) * clamp01(exp(-shore_depth) - 0.3678/*e^-1*/) * 1.5818/*1/e^-1*/;
		shore_power = clamp01((abs(shore_grad.x)+abs(shore_grad.y))*200) * (1 - shore_depth);
		//blend_alpha -= clamp01((shore_power - 0.65) * 5);

		shore_power = shore_power * (1-clamp01(((grad_1.y) * shore_power + (grad_2.y) * (1-shore_power)) * uShoreParam.y * (1 -shore_power)));
		//shore_power = clamp01(shore_power * uShoreParam.x + shore_power * ( 1 - (shore_val.x)) * uShoreParam.y);
		roughness = max(roughness, shore_power);
		light_buf_color += shore_power * 20;
#endif

	#if (NOISE_TEX_TYPE == NOISE_TEX_ENABLE)
		{
			vec3 pos_w = multMtx34Vec3(cInvView, getVarying(vPosView));
			vec4 noise = texture(cNoise3D, pos_w * NOISE_TEX_CRD_SCALE + NOISE_TEX_CRD_ADD).rgba;
			vec4 noise_2 = texture(cNoise3D, pos_w * NOISE_TEX_CRD_SCALE*uBubbleParam1.y - NOISE_TEX_CRD_ADD*uBubbleParam1.y).rgba;
			//bubble_power += clamp01(getVarying(vDisplacement).x * uBubbleParam1.y) + clamp01(getVarying(vDisplacement).z * uBubbleParam1.z);
			//bubble_power += abs(nrm.x) * uBubbleParam1.y + abs(nrm.z) * uBubbleParam1.z;
			bubble_power_depth *= uBubbleParam1.z;
			bubble_power_depth += abs(nrm.x * nrm.z) * uBubbleParam1.w;
			light_buf_color.rgb += clamp01(bubble_power) * uBubbleColor.rgb * noise.rgb + noise_2.rgb * noise.rgb *  uBubbleColor.rgb * bubble_power_depth;
		}
	#endif

		// 屈折ではベースカラー自体を減らすことでディフューズもメタルも影響を消していく
		base_color *= 1.0 - refractness;

		// F0 を金属非金属で補間
		vec3 F0 = mix(vec3(FRESNEL_0), base_color, metalness);

		// 環境 BRDF で反射率計算 (Environment BRDF)
		vec3 reflectance;
		calcEnvDFG(reflectance, F0, roughness, N_V);
		vec3 subsurface = 1.0 - reflectance;  // 表面下に潜る光
		vec3 indirect_color_base;
		float dist_intensity;
		#if (TRANSLUCENT_TYPE == TYPE_INDIRECT)
		{
			vec3 refract_ratio = subsurface * refractness;
			subsurface -= refract_ratio; // 屈折を引いた分がさらに表面下に
			
			vec3 refract_color = REFRACT_COLOR;
		
			vec3 indirect_color = texture(cFrameBufferTex, uv).rgb;
			// ビューデプス差分により、インダイレクトカラーが減衰する
			#if (LINEAR_DEPTH_OPA_TYPE == LINEAR_DEPTH_OPA_ENABLE)
				
				dist_intensity = -LINEAR_DAMP_SCALE * ((gl_FrontFacing ? depth_view_diff : -getVarying(vPosView).z) + LINEAR_DAMP_START);
				dist_intensity = clamp01(1.0 - exp2(dist_intensity));
				indirect_color.rgb *= (1 - dist_intensity); 
				indirect_color.rgb += COLOR_DAMP.rgb * (dist_intensity);
			#endif
			indirect_color_base =  refract_ratio * REFRACT_COLOR * indirect_color;
			light_buf_color += indirect_color_base;
		}
		#elif (TRANSLUCENT_TYPE == TYPE_XLU)

		#endif // 

		// 反射 キューブマップスペキュラ
		vec4 reflect_color = vec4(0.0);
		vec3 fetch_dir = ray_reflect_w;
	//	fetchCubeMapConvertHdr(reflect_color, cTexCubeMapRoughness, fetch_dir, 5.0 * ROUGHNESS);
		fetchCubeMapConvertHdr(reflect_color, cTextureMaterialLightCube, fetch_dir, 5.0 * roughness);
		light_buf_color += reflectance * reflect_color.rgb;
	
		// 残った光がアルベド（ディフューズ）になる
		vec3 albedo = base_color * (1.0 - metalness);
		vec3 rest_albedo = albedo * subsurface;
	
		// スキャタリング

		{
	//		vec3 lit_to_pos = -cDirLightViewDirFetchPos.xyz;
	//		float phase = calcScatterPhaseFunctionSchlick(PHASE_K, PHASE_BACK_K, PHASE_RATE, dot(lit_to_pos, pos_to_eye)); //FIXME uIsoRateの名前変更
	//		light_buf_color += (phase * folding * SCATTER_SCALE) * REFRACT_COLOR * dir_light_color;
		}
			// 遠くもアルファ投下してみるテスト
		#if (FAR_FLAT_TYPE == FAR_FLAT_ENABLE)
		{	
		//	blend_alpha *= 1-getVarying(vFarParam).y;
		}
		#endif
	
		// ディレクショナルライト
		// 太陽のGGXスペキュラ
	//	if (IS_USE_FORWARD_GGX_SPECULAR == 1)
	#if (FORWARD_GGX_SPECULAR_TYPE == FORWARD_GGX_SPECULAR_ENABLE)
		{
			FragInfo frag;
			frag.N = view_nrm;
			frag.view_pos = getVarying(vPosView);
			frag.V = pos_to_eye;
			
			setMaterialParam(frag, base_color.rgb, roughness, metalness);
			#if 0
			frag.base_color.rgb = base_color.rgb;
			frag.metalness = METALNESS;
			setRoughness(frag, roughness);
			calcColorsByMetalness(frag);
			#endif // 0
			LightInfo light;
			light.L = cDirLightViewDirFetchPos.xyz;
			calcN_L(light, frag);
			calcN_H(frag, light);
			calcN_V(frag);
			calcSpecularGGX(frag, light);
			light_buf_color += light.spc_intensity * dir_light_color;
		}
	#endif
		float diffuse = calcDiffuseIntensity(view_nrm, cDirLightViewDirFetchPos.xyz);
		light_buf_color += albedo * dir_light_color * diffuse; // Deferred Shading に合わせるために rest_albedo は使わない
		
		// AO影
		#if ( AO_SHADOW_TYPE == AO_SHADOW_ENABLE )
			// プロジェクションからビューに変換
			vec3 view = getVarying(vPosView);
			// ビューからワールドに変換				
			vec3 world = multMtx34Vec3(cInvView, view.xyz);
			vec2 ao_tcrd = multMtx44Vec4(uAoDepthViewProj, vec4(world, 1.0)).xy;
			float power = (1 - uAoShadowColor.a) + uAoShadowColor.a *  texture(cTextureAoDepthMap, ao_tcrd).r;
			vec3 shadow_after = light_buf_color.rgb * power;
			light_buf_color.rgb = shadow_after + (light_buf_color.rgb - shadow_after) * uAoShadowColor.rgb;
		#endif

		#if SPHERE_CURVE_TYPE == SPHERE_CURVE_ENABLE
			float tone = pow(N_V, SPHERE_CURVE_TONE_POW)*SPHERE_CURVE_SLOPE;
			float peak_pos = N_V - SPHERE_CURVE_PEAK_POS;
			float peak = exp2(-peak_pos*peak_pos*100.0*SPHERE_CURVE_PEAK_POW)*SPHERE_CURVE_PEAK_INTENSITY;
			float sphere_value = clamp01(tone + peak);

			light_buf_color += getVarying(dir_light_color).rgb * REFRACT_COLOR * (sphere_value * 
				calcScatterPhaseFunctionSchlick(SPHERE_CURVE_FRONT_K,SPHERE_CURVE_BACK_K,SPHERE_CURVE_FRONT_BACK_RATE, dot(pos_to_eye, -cDirLightViewDirFetchPos.xyz))); 
		#endif
	} // TYPE_OCEAN
	#endif
	
	#if (RENDER_TYPE == TYPE_FORWARD)
	{
		oLightBuf = vec4(light_buf_color.rgb, blend_alpha);
	}
	#else
	{
		oLightBuf	= vec4(light_buf_color, blend_alpha/* * uModelAlphaMask*/);
		// ディファード
		#if (RENDER_TYPE == TYPE_DEFERRED_XLU)
		{
			encodeWorldNrm(oWorldNrm.xy, nrm);
			oWorldNrm.zw	= vec2(0.0, blend_alpha);	// World Nrm(16) MotionVector(16)		

			oBaseColor	= vec4(BASE_COLOR, blend_alpha);
			
		}
		#elif (RENDER_TYPE == TYPE_DEFERRED_OPA)
		{
			// 出力要素をパッキング
			vec4 gbuf_base_color;
			encodeGBufferBaseColor(gbuf_base_color, BASE_COLOR, ROUGHNESS, metalness, 0.0, nrm);
			encodeWorldNrm(oWorldNrm.xy, nrm);
			oWorldNrm.zw	= vec2(0.0, 0.0);	// World Nrm(16) MotionVector(16)		
			oBaseColor	= gbuf_base_color;		// BaseColorRGB(24) Roughness(4) Metalness + SSS(3) NormalZSign(1)
			oMotionVec = vec4(0.0);
			oNormalizedLinearDepth.r = getVarying(vNormalWorldDepthView).w;
		}
		#endif
	}
	#endif // RENDER_TYPE
#endif // RENDER_TYPE
}

#endif // AGL_FRAGMENT_SHADER
