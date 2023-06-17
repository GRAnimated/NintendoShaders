/**
 * @file	alCloudSphereRaymarch.glsl
 * @author	Matsuda Hirokazu  (C)Nintendo
 *
 * @brief	球モデルをバウンディングとしてレイマーチする
 */

#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable // 明示的な場所指定には必要。無いと GPU ハング。
#endif

#include "alDeclareUniformBlockBinding.glsl"
#include "alDefineSampler.glsl"
#include "alMathUtil.glsl"
#include "alDefineVarying.glsl"
#include "alPasPhysicalModelParam.glsl"
#include "alETMUtil.glsl"

#define IS_USE_TEXTURE_BIAS		(0)
#include "alHdrUtil.glsl"
#include "alFetchCubeMap.glsl"

#define RENDER_TYPE				(0)
#define RENDER_SCENE			(0)
#define RENDER_ETM				(1)

#define USING_ETM				(0)
#define NO_ETM					(0)
#define ETM_BEERS_LOW			(1)
#define ETM_POWDER				(2)
#define ETM_BEERS_POWDER		(3)

#if (RENDER_TYPE == RENDER_SCENE)
#include "alDeclareMdlEnvView.glsl"
#endif // RENDER_SCENE

#define USING_ADAPTIVE	(0)
#define ITER_NUM		(8)

BINDING_SAMPLER_DIR_LIT_COLOR	uniform sampler2D cDirectionalLightColor;
BINDING_SAMPLER_DEPTH	uniform sampler2D cTextureLinearDepth;	
BINDING_SAMPLER_ENV_CUBE_MAP_ROUGHNESS	uniform samplerCube cTexCubeMapRoughness;
uniform sampler3D uVolumeTex;
uniform sampler2D uEtmTex;
uniform sampler2D uEtmDistTex;

/**
 *	ETM 変換行列
 */
layout(std140) uniform ETMMtxUbo
{
	EtmMtx	uEtmMtx;
};

layout(std140) uniform RaymarchSceneViewUbo
{
	vec4 uWorldMtx[3];			// ワールドマトリックス
	vec4 uInvViewWorld[3];		// ビュー空間のレイをローカルに変換
	vec4 uPVW[4];				// local -> world -> view -> proj
	vec4 uWorldETMViewMtx[3];	// local -> world -> ETM View
	vec4 uLocalCamPos;			// ローカルから見たカメラ位置
};

layout(std140) uniform CloudParamUbo
{
	vec4	uParam;		// x : dist scale of extinction σ,  y : k of forward scatter,  z : k of back scatter,  w : forward - back mix
	vec4	uCoeff;		// x : absorption coeff
	vec4 	uParam2;	// x : sphere opacity pow,  y : volume tex fetch coord scale,  z : test start end scale
	vec4	uParam3;	// xyz : cloud color,  w : irradiance scale
	vec4	uParam4;	// x : Powder Effect Pow,  y : Powder Scale,  z : Directional Light Scale,  w : density scale
	vec4	uSmooth;	// xy : density smooth step edge,  zw : sphere smooth step edge
	vec4	uEmission;	// rgb : Emission Color
	vec4	uTexOffset;	// xyz : volume tex fetch offset
};

#define EXTINCTION_DIST_SCALE 	uParam.x
#define CLOUD_KF				uParam.y
#define CLOUD_KB				uParam.z
#define CLOUD_KF_KB_MIX			uParam.w
#define SPHERE_OPA_POW			uParam2.x
#define VOL_CRD_SCALE			uParam2.y
#define DENSITY_SMOOTH_0		uSmooth.x
#define DENSITY_SMOOTH_1		uSmooth.y
#define SPHERE_SMOOTH_0			uSmooth.z
#define SPHERE_SMOOTH_1			uSmooth.w
#define CLOUD_COLOR				uParam3.xyz
#define IRRADIANCE_SCALE		uParam3.w
#define POWDER_EFFECT_POW		uParam4.x
#define POWDER_EFFECT_SCALE		uParam4.y;
#define DIRECTIONAL_LIGHT_SCALE	uParam4.z
#define DENSITY_SCALE			uParam4.w
#define EMISSION_COLOR			uEmission.xyz
#define TEX_OFFSET				uTexOffset.xyz

#define ABSORB_COEFF			uCoeff.x

#define TEST_START_END_SCALE	uParam2.z

DECLARE_VARYING(vec3,	vWorldPos);
DECLARE_VARYING(vec3, 	vViewPos);
DECLARE_VARYING(vec4,	vDirLitColor);
DECLARE_NOPERS_VARYING(vec4,	vPosProj);// シーンのリニアデプスをフェッチするため

#if defined(AGL_VERTEX_SHADER)
/********************************************************
 *	頂点シェーダ
 */

layout( location = 0 ) in vec3 aPosition;

void main()
{
	#if (RENDER_TYPE == RENDER_SCENE)
	{
		gl_Position = multMtx44Vec3(uPVW, aPosition);
		getVarying(vWorldPos) = multMtx34Vec3(uWorldMtx, aPosition);
		getVarying(vViewPos)  = multMtx34Vec3(cView, getVarying(vWorldPos));
		getDirectionalLightColor(getVarying(vDirLitColor), cDirectionalLightColor);
		getVarying(vPosProj).xy = gl_Position.xy/gl_Position.w;
	}
	#elif (RENDER_TYPE == RENDER_ETM)
	{
		gl_Position = multMtx44Vec3(uEtmMtx.uToETMMtx, aPosition);
		getVarying(vViewPos)  = multMtx34Vec3(uWorldETMViewMtx, aPosition);
	}
	#endif // RENDER_TYPE
}

#elif defined(AGL_FRAGMENT_SHADER)
/********************************************************
 *	フラグメントシェーダ
 */

out vec4 oColor;
#if (RENDER_TYPE == RENDER_ETM)
out vec4 oDist;
#endif // RENDER_ETM

const float eps = 0.01;
const float sphere_r = 0.5 + eps;

/**
 *	長さの二乗が半径 0.5 の球の中かどうか
 */
bool isInSphere(vec3 local_pos)
{
#if 1
	return (dot(local_pos, local_pos) < sphere_r*sphere_r);
#else
	return true;
#endif
}

#define MARCH_ITER_NUM	ITER_NUM

void main()
{
	vec3 view_pos = getVarying(vViewPos);

	#if (RENDER_TYPE == RENDER_SCENE)
		// シーンのリニアデプスを参照
		vec2 l_depth_uv = (getVarying(vPosProj).xy + 1.0) * 0.5;
		l_depth_uv.y = 1.0 - l_depth_uv.y;
		float l_depth = texture(cTextureLinearDepth, l_depth_uv).r;
		// 海面位置とデプス位置の差
		float scene_depth = ( l_depth * cRange + cNear );

		// view_pos をデプスの位置までにする
		float depth = abs(view_pos.z);
		float min_depth = min(depth, scene_depth);
		view_pos *= min_depth / depth;
		vec3 pos_to_eye_dir_v = -normalize(view_pos);
		vec3 lit_to_pos_v = -cDirLightViewDirFetchPos.xyz;

		// Mie 散乱
		float cos_ = dot(lit_to_pos_v, pos_to_eye_dir_v);
		float phase = calcScatterPhaseFunctionSchlick(CLOUD_KF, CLOUD_KB, CLOUD_KF_KB_MIX, cos_);
		vec3 dir_lit_color = getVarying(vDirLitColor).rgb * (phase * DIRECTIONAL_LIGHT_SCALE);
	#endif // RENDER_TYPE

	// 反転描画に対応してカメラを雲の中に突っ込めるようにする
	// ローカルの位置へ変換。境界モデルの表面 or シーンのデプスにくる。ここがレイマーチ終了点
	vec3 local_pos_end = multMtx34Vec3(uInvViewWorld, view_pos);
	// カメラからのレイ
	vec3 local_ray = normalize(local_pos_end - uLocalCamPos.xyz);

	// 判別式 dot(C, V)^2 - length(C)^2 + r^2
	float CdotV = dot(uLocalCamPos.xyz, local_ray);
	float Clen2 = dot(uLocalCamPos.xyz, uLocalCamPos.xyz);
	float disc = CdotV*CdotV - Clen2 + sphere_r*sphere_r; // 球の半径があるのでローカル座標でやるしかない
	float disc_sqrt = sqrt(disc);
	float d_small, d_large;
	#if 1
	{
		d_small = -CdotV - disc_sqrt;
		d_large = -CdotV + disc_sqrt;
	}
	#else
	// 桁落ちに注意して、根を求める by [数値計算の常識 伊理正夫先生]
	// -b +- √(b^2 - 4ac) にて 0<b ならば - の方を求め、残り一つを根と係数の関係 x2 = (c/a)/x1 より求める
	if (0 < CdotV)
	{
		d_small = -CdotV - disc_sqrt;
		d_large = (Clen2 - sphere_r*sphere_r)/d_small;
	}
	else
	{
		d_large = -CdotV + disc_sqrt;
		d_small = (Clen2 - sphere_r*sphere_r)/d_large;

	}
	#endif
	// モデルを描画しているので必ず解は存在する
	// d_small < 0 のときはカメラよりも後ろになってしまうのでカメラ位置からマーチ始める。
	// 本当はニアプレーンを考慮したいが・・・
	vec3 local_pos_begin_sphere = uLocalCamPos.xyz + local_ray * d_small;

	#if (RENDER_TYPE == RENDER_ETM)
		vec3 local_pos_begin = local_pos_begin_sphere;
		// 距離の start, end をMRT出力で記録
		// far は view_pos
		vec3 view_pos_begin = multMtx34Vec3(uWorldETMViewMtx, local_pos_begin);
		// [0, 1] の深度に変換
		float start_dist 	= clamp01((-view_pos_begin.z - ETM_NEAR(uEtmMtx))*ETM_INV_RANGE(uEtmMtx));
		float end_dist 		= clamp01((-view_pos.z - ETM_NEAR(uEtmMtx))*ETM_INV_RANGE(uEtmMtx));
//		float mid_dist = (start_dist + end_dist) * 0.5;
//		float mit_start_len = 
		oDist = vec4(1.0 - start_dist, end_dist, 0.0, 0.0);
	#endif // RENDER_ETM

	#if (RENDER_TYPE == RENDER_SCENE)
		vec3 local_pos_begin = (d_small < 0.0) ? uLocalCamPos.xyz : local_pos_begin_sphere;
		// レイマーチ開始点におけるイラディアンスを求める。内部で求めると重い。
		vec3 world_dir = rotMtx34Vec3(uWorldMtx, local_pos_begin);
		// イラディアンス
		vec4 irradiance;
		fetchCubeMapIrradianceScaleConvertHdr(irradiance, cTexCubeMapRoughness, world_dir);
		irradiance *= IRRADIANCE_SCALE;
	#endif // RENDER_TYPE

	// ETM を用いた描画で ETM のテクスチャ座標を求めるが、端点の補間で高速化する
	#if ((RENDER_TYPE == RENDER_SCENE) && (USING_ETM != NO_ETM))
	vec4 etm_coord_begin = multMtx44Vec3(uEtmMtx.uFetchETMMtx, local_pos_begin);
	vec4 etm_coord_end   = multMtx44Vec3(uEtmMtx.uFetchETMMtx, local_pos_end);
	#endif
		
	vec4 color = vec4(0.0); // アルファは１になったら不透明
	float T = 1.0; // Transmittance
	const float epsilon = 0.01;

	// レイマーチの始点と終点を結ぶベクトル
	vec3 local_pos_begin_to_end = local_pos_end - local_pos_begin; // ニアと終点
	vec3 local_pos_begin_to_end_sphere = local_pos_end - local_pos_begin_sphere; // 始点と終点

	// イテレーション情報
	float iter_depth = 0.0;
	float iter_depth_limit = dot(local_ray, local_pos_begin_to_end);
	float inv_iter_depth_limit = 1.0 / iter_depth_limit;
	float iter_depth_limit_sphere = dot(local_ray, local_pos_begin_to_end_sphere);
	// カメラが中に入っていったらクオリティを落として処理をあげる
	float iter_div_scale = mix(1.0, 0.75, iter_depth_limit/iter_depth_limit_sphere);
#if (USING_ADAPTIVE == 0)
	// 始点と終点の間を MARCH_ITER_NUM 分割すると必ず MARCH_ITER_NUM だけマーチしてしまうので重いがクオリティは高い
	// 上は無駄が無いがカメラが突っ込んだときにサンプル数が多くて処理が重い
	// 下はサンプルの分布に無駄があるが、カメラが突っ込んだときにマーチがすぐに終わって処理が軽い
//	float iter_depth_add = iter_depth_limit / MARCH_ITER_NUM;
	float iter_depth_add = iter_div_scale*2.0*sphere_r / MARCH_ITER_NUM;
#else
	// 経路の中を分割するのと球の半径を元に一定分割するのを密度によって混ぜる
	// 最初は直径を分割していたがクオリティが低かったので半径にしてみている
	float iter_depth_add_high = iter_depth_limit / MARCH_ITER_NUM;
	float iter_depth_add_low = iter_div_scale*2.0*sphere_r / MARCH_ITER_NUM;
#endif

	float inv_ext_dist_scale = 1.0 / EXTINCTION_DIST_SCALE;
	for (int i=0; i<MARCH_ITER_NUM; ++i)
	{
		if (iter_depth_limit < iter_depth) break;
		vec3 iter_pos = local_pos_begin + iter_depth * local_pos_begin_to_end;

		// 球の外側に行くほど薄くする [-0.5, 0.5] の球なので二倍して中心からのベクトルの長さが１になるようにする
		vec3 nrm_sphere_pos = 2.0 * iter_pos;
		#if 1
			float sphere_opa_base = 1.0 - clamp01(dot(2.0*iter_pos, 2.0*iter_pos));
			float sphere_opa = pow(sphere_opa_base, SPHERE_OPA_POW);
		#else
		float sphere_opa_base = clamp01(dot(nrm_sphere_pos, nrm_sphere_pos));
		float sphere_opa = 1.0 - sphere_opa_base;
	//	float sphere_opa = smoothstep(SPHERE_SMOOTH_0, SPHERE_SMOOTH_1, 1.0 - sphere_opa_base);
	//	float sphere_opa_base = 1.0 - clamp01(dot(nrm_sphere_pos, nrm_sphere_pos));
		sphere_opa = pow(sphere_opa, SPHERE_OPA_POW);
		#endif

		#if (USING_ADAPTIVE == 1)
		float iter_depth_add = mix(iter_depth_add_low, iter_depth_add_high, sphere_opa);
		#endif

		float iter_depth_prev = iter_depth;
		float iter_depth_next = clamp(iter_depth + iter_depth_add, 0, iter_depth_limit);
		float actual_depth_add = iter_depth_next - iter_depth_prev;

		// 3D ボリュームテクスチャを引いて不透明度を取得する
		// 中心が原点で半径が 0.5 の球なので [-0.5, 0.5] の座標を取るので 0.5 足せばよい
		vec3 vol_crd = iter_pos + 0.5;
		vec4 vol = texture(uVolumeTex, vol_crd * VOL_CRD_SCALE + TEX_OFFSET);
		#if 0
			float dens = (vol.r + 0.5*vol.g + 0.25*vol.b + 0.125*vol.a)/(1.0+0.5+0.25+0.125);
		#else
			// 上の方ほどくっきり、下の方は Perlin を混ぜた Whispy な形
			vol.r = mix(vol.r, vol.g, vol_crd.z);
			float dens = (vol.r + 0.5*vol.b + 0.25*vol.a)/(1.0+0.5+0.25);
		#endif // 0
		dens = smoothstep(DENSITY_SMOOTH_0, DENSITY_SMOOTH_1, clamp01(dens*DENSITY_SCALE));
		dens *= sphere_opa;

		// 始点と終点のどの辺りにいるか
		float iter_rate = clamp01(iter_depth * inv_iter_depth_limit);
		float rho = -dens * ABSORB_COEFF * actual_depth_add;
		#if (RENDER_TYPE == RENDER_SCENE)
		{
			// 経路の合計の exp であっても良いが deltaT を乗算でも良い
			float deltaT = exp(rho * EXTINCTION_DIST_SCALE);
			T *= deltaT;

			// 不透明までいったらその先はマーチしても意味が無い
			if (T <= epsilon)	break;
			// 雲の色とは、密度が高い場合に周りの粒子からも光を受け取ることを考慮すると1以上になる
			vec3 cloud_color = CLOUD_COLOR * dens;
			#if (USING_ETM != NO_ETM)
				// ETM を見て太陽からの光のトランスミッタンスを適用する。ついでにパウダーエフェクトも
				float T_etm = 1.0;
				// 全ての点から UV 座標を求めるのは大変なので端点の UV を補間する
				vec4 etm_coord = mix(etm_coord_begin, etm_coord_end, iter_rate);
				// 奥行きの範囲を取得
				vec2 start_end;
				getTraversalStartEnd(start_end, etm_coord.xy, uEtmDistTex);
				// DCT 係数を取得
				vec4 dct_coef = texture(uEtmTex, etm_coord.xy);

				// etm_coord.z も [-1, 1] -> [0, 1] になっているっぽい。参照：ShadowMatrixUpdator
				float x = etm_coord.z;
				float d_max = start_end.y;
				x = x*DIST_SCALE + CAM_TO_NEAR_DIST; d_max *= DIST_SCALE;
				calcTransmittanceByEtm4(T_etm, dct_coef, x, d_max, TRANSMITTANCE_EXP_SCALE, uDctWeight);
				// なぜかひっくり返っている
				T_etm = clamp01(1.0 - T_etm);

				// パウダーエフェクト
				float powder = pow(1.0 - T_etm, POWDER_EFFECT_POW);
				powder = 1.0 - (1.0 - powder)*POWDER_EFFECT_SCALE;
				#if (USING_ETM == ETM_POWDER)
					T_etm = powder;
				#elif (USING_ETM == ETM_BEERS_POWDER)
					T_etm *= powder;
				//	T_etm = min(T_etm, powder);
				#endif

				vec3 light = cloud_color * (dir_lit_color * T_etm + irradiance.rgb);
			#else
				vec3 light = cloud_color * (dir_lit_color + irradiance.rgb);
			#endif
		//	color.rgb += light * (T * actual_depth_add); // 積分の長さ iter_depth_add を忘れずに。
			// 台形積分？
			light.rgb += EMISSION_COLOR * dens;
			color.rgb += ((1-deltaT)*inv_ext_dist_scale * actual_depth_add * T) * light;
			color.a += (1.0 - deltaT)*(1.0 - color.a);
		}
		#elif (RENDER_TYPE == RENDER_ETM)
		{
			// ローカル位置を ETM View に変換して深度を取り出すのは大変なので補間で求める
			float x = clamp01(mix(start_dist, end_dist, iter_rate));
			// DCT 係数を計算
			float d = clamp01(x - start_dist); // 雲が始まってからの距離
			float d_max = end_dist;
			x = x*DIST_SCALE + CAM_TO_NEAR_DIST; d *= DIST_SCALE; d_max *= DIST_SCALE;
			vec4 dct_coef;
			calcEtmDctCoefficient(dct_coef, x, d, d_max, rho, uDctWeight);
			color += dct_coef * actual_depth_add * DRAW_DCT_SCALE;
		}
		#endif // RENDER_SCENE
		iter_depth = iter_depth_next;
	}

	#if (RENDER_TYPE == RENDER_SCENE)
	{
		oColor = color;
	}
	#elif (RENDER_TYPE == RENDER_ETM)
	{
		oColor = color;
	}
	#endif // RENDER_SCENE
}

#endif
