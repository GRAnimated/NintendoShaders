/**
 * @file	alLightingFunction.glsl
 * @author	Yosuke Mori  (C)Nintendo
 *
 * @brief	ライティング関数
 */
#ifndef AL_LIGHTING_FUNCTION_GLSL
#define AL_LIGHTING_FUNCTION_GLSL

#if !defined(BINDING_UBO_LIGHT_ENV)
#include "alDeclareUniformBlockBinding.glsl"
#endif

#define		IMPORT_LIGHTING_FUNCTION

/*
	等方性反射
	vec3 H = normalize(V + L);
	float spec = dot(N, H);
	異方性反射
	vec3 H = normalize(V + L);
	HdotA = dot(H, i_anisoAngle);
	aniso_spec = 1.0 - HdotA * HdotA;
 */

/**
 *	ライトごとに変わらないもの
 */
struct FragInfo
{
	vec4	base_color;		// rgb : base color
	vec4	albedo_color;
	vec4	roughness;	// x : raw roughness,  y : for Analytical Light GGX clamp roughness,  z : y^2
	vec3	N;		// nrm
	vec3	V;		// pos_to_eye
	vec3	view_pos;
	// スペキュラに必要なもの
	vec3	R;		// 反射ベクトル
	vec3	F0;		// 正面反射時のフレネル
	float	N_V;
	float	metalness;
	float	spc_cavity_coef; // スペキュラの係数 UE4のスペキュラのページより
	float	sss;
};

/**
 *	ライト計算に必要な各種情報
 */
struct LightInfo
{
	// 以下はライトごとに異なる
	float	N_H;
	float	N_L;
	float	diffuse_attn;	// ディフューズ距離減衰
	float	specular_attn;	// スペキュラ距離減衰
	float	lit_dist2;		// 距離の二乗
	float	inv_lit_dist;	// 1/距離
	float	inv_unit_scale_sqr;
	float 	dist_inv_r_sqr; // discard 判定用
	vec3	spc_intensity;
	vec3	lit_to_pos;		// フラグメントからライトへのベクトル
	vec3	L; // pos_to_light dir
	vec3	H;
	// Specular GGX
	float 	D;
	float	spc_scale; // 強さを調整したり正規化スケールを格納したり
	// for debug
	float 	debug;
};

#define calcN_V(frag)	(frag.N_V = dot(frag.N, frag.V))

/**
 *	プロジェクト固有のパラメータ
 */
BINDING_UBO_LIGHT_ENV uniform LightEnv // @@ id="cLightEnv"
{
	float	uInvUnitScaleSqr;
	float	uLineLightAntiArtifact;
	float	uMinRoughnessGGX;
	float	uSphereLightDiffuseAdd; // シェーディングポイントと同じ場所にならないように。
	float	uSpecularScale;
};

/**
 *	初期化
 */
#define InitLightInfo(light) \
{ \
	light.diffuse_attn			= 0.0; \
	light.specular_attn			= 0.0; \
	light.lit_dist2				= 0.0; \
	light.inv_lit_dist			= 0.0; \
	light.inv_unit_scale_sqr	= uInvUnitScaleSqr; \
	light.dist_inv_r_sqr		= 0.0; \
	light.lit_to_pos			= vec3(0.0); \
	light.D						= 0.0; \
	light.spc_scale				= uSpecularScale; \
}

/**
 *	以下は uniform 用
 */
struct PointLight
{
	vec4	mVposInvR;	// xyz : view pos,	w : 1/boudary
	vec4	mColorSphR;	// rgb : color,		a : sphere radius
};

struct SpotLight
{
	vec4	mVposInvR;		// xyz : view pos,	w : 1/boundary
	vec4	mColorSphR;		// rgb : color,		a : sphere radius
	vec4	mVdirAngPow;	// xyz : view dir,	w : angular power
	vec4	mAttn;			// x : 1/(1-cos)  y : cos/(1-cos)
};

struct LineLight
{
	vec4	mVposInvR;		// xyz : view pos,		w : 1/boudary
	vec4	mColorSphR;		// rgb : color,			a : sphere radius
	vec4	mVpos2InvLen2;	// xyz : view end pos,	w : 1/(len * len)
};

/**
 *	フラグメント情報の設定
 */
#define setNV(frag, nrm, pos_to_eye)	\
{										\
	frag.N = nrm;						\
	frag.V = pos_to_eye;				\
}

/**
 *	フラグメント情報の設定
 *	R は GGX のスフィアライトで使う
 */
#define setNVR(frag, nrm, pos_to_eye)				\
{													\
	setNV(frag, nrm, pos_to_eye);					\
	frag.R = normalize(reflect(-frag.V, frag.N));	\
	calcN_V(frag);									\
}

/**
 *	ラフネス、メタルネスを設定し付加情報も設定
 *	albedo_color はスペキュラとのエネルギー保存を考える。参考：Substance Player
 *
 *	uMinRoughnessGGX で持ち上げつつラフネスのレンジは有効活用する
 *	Analytical Light のラフネスは以下の式
 *	Roughness = uMinRoughnessGGX + clamp_rough * (1.0 - uMinRoughnessGGX);
 *	これは mix で表現が出来る
 *
 *	ラフネスの高い非金属にてスペキュラが強くなりすぎるのでスペキュラスケールとしての cavity も算出
 *	ラフネスの二乗カーブでやってみる。 
 */
#define setMaterialParam(frag, base_col, rough, metal)												\
{																									\
	frag.base_color.rgb = base_col.rgb;																\
	frag.metalness = metal;																			\
	float clamp_rough = clamp01(rough);																\
	frag.roughness.x = clamp_rough;																	\
	frag.roughness.y = mix(uMinRoughnessGGX, 1.0, clamp_rough);										\
	frag.roughness.z = frag.roughness.y * frag.roughness.y;											\
	frag.spc_cavity_coef = mix(1.0 - clamp_rough*clamp_rough, 1.0, frag.metalness) * 0.5;			\
	frag.F0	= mix(vec3(0.04), frag.base_color.rgb, frag.metalness);									\
	frag.albedo_color.rgb	= (frag.base_color.rgb * (1.0 - frag.metalness))*(vec3(1.0) - frag.F0);	\
}

// ライト用のラフネス2乗を取得
#define getGGXRoughness2(frag)	(frag.roughness.z)

#if (LPP_ENABLE_DISCARD == 1 && defined(AGL_FRAGMENT_SHADER))
	#define IF_DISCARD_BOUND_OUT(light) { if (1.0 < light.dist_inv_r_sqr) discard; }
#else
	#define IF_DISCARD_BOUND_OUT(light)
#endif

/**
 *	light.L を求める
 *	スポットライトの角度減衰計算時にこの部分だけ使いたい
 */
#define calcL(light, vec)										\
{																\
	light.lit_to_pos = vec;										\
	light.lit_dist2 = dot(light.lit_to_pos, light.lit_to_pos);	\
	light.inv_lit_dist = inversesqrt(light.lit_dist2);			\
	light.L = -light.lit_to_pos * light.inv_lit_dist;			\
}

/**
 *	ライトからフラグメントへの位置を設定する
 *	light.lit_to_pos に vec を代入することで加算の式も vec に渡せるようにしていることに注意
 */
#define setLightToPos(light, vec, inv_r)						\
{																\
	calcL(light, vec);											\
	light.dist_inv_r_sqr = light.lit_dist2 * inv_r * inv_r;		\
	IF_DISCARD_BOUND_OUT(light)									\
}

/**
 *	ハーフベクトル計算
 */
#define calcN_H(frag, light)					\
{												\
	vec3 add_vec = light.L + frag.V;			\
	NORMALIZE_EB(light.H, add_vec);			\
	light.N_H = clamp01(dot(frag.N, light.H));	\
}

/**
 *	スペキュラ GGX
 */
void calcSpecularGGX(in	FragInfo frag, inout LightInfo light)
{
	float alpha = getGGXRoughness2(frag);
	float L_H = clamp01(dot(light.L, light.H));
	float D;
	{
		float alpha_2 = alpha*alpha;
		float denom = light.N_H * light.N_H * (alpha_2 - 1.0) + 1.0;
		float pi_denom_2 = PI * denom * denom;
		D = alpha_2 / max(pi_denom_2, 0.0005);	//桁落ちでpi_denom_2が0.0と判断されてDがNanに飛ぶ,この数値は適当
	}
	vec2 FV_helper;
	{
		// F
		float F_a, F_b;
		float dotLH5 = pow(1.0 - L_H, 5);
		F_a = 1.0;
		F_b = dotLH5;
		// V
		float k = alpha * 0.5;
		float k2 = k*k;
		float invK2 = 1.0 - k2;
		// absNV * NL を分子に入れることでラフネスが１のときにかなり強く減衰させることができるらしい
//		float vis_numerator = min(frag.N_V, light.N_L);
		float vis_numerator = abs(frag.N_V) * light.N_L;
//		float vis_numerator = 1.0;
		float vis = vis_numerator / (L_H * L_H * invK2 + k2);
		FV_helper.x = (F_a - F_b)*vis;
		FV_helper.y = F_b*vis;
		// デバッグ用
		light.debug = light.N_L;
	}
	vec3 FV = frag.F0 * FV_helper.x + FV_helper.y;
	
	light.spc_intensity = FV * (light.N_L * D * frag.spc_cavity_coef * light.spc_scale);
}

/**
 *	正規化GGX
 */
void calcSpecularGGXNormalization(in FragInfo frag, inout LightInfo light, float radius)
{
	#if (IS_USE_SPHERE_GGX_SPECULAR_NORMALIZE == 1)
	{
		// UE4 の資料より
		float alpha = getGGXRoughness2(frag);
		float alpha_dash = clamp01(alpha + radius * light.inv_lit_dist * 0.5);
		float nrm_ = alpha / alpha_dash;
		light.spc_scale *= nrm_ * nrm_;
	}
	#elif (IS_USE_SPHERE_GGX_SPECULAR_NORMALIZE == 2)
	{
		#if 0
		{
			// α’ による正規化項 1/(πα^2)
			float alpha_dash = clamp01(getGGXRoughness2(frag) * radius * light.inv_lit_dist * 0.5);
			light.spc_scale *= PI / (alpha_dash * alpha_dash);
		}
		#else
		{
			// 上記は白飛びしすぎなので何かが間違っている・・・
			light.spc_scale *= clamp01(getGGXRoughness2(frag) * radius * light.inv_lit_dist * 0.5);
		}
		#endif
	}
	#endif
}

#if 0
/**
 *	スペキュラ反射を計算する
 *	金属には色が付く。
 *	その場合、ディフューズ反射が入ってしまうので、アルベドを黒にしていく必要がある
 */
vec3 calcSpecular(in vec4 base_color, in vec3 light, in float metalness)
{
	return mix(light, base_color.rgb * light, metalness);
}
#endif // 0

/**
 *	GGXの計算、方向ベース
 */
#define calcSpecularGGXFromDir(intensity, light_dir, half_vec, normal, roughness)	\
{																					\
    float N_L = -dot( normal, light_dir );											\
    float N_H = -dot( normal, half_vec );											\
	N_L = clamp01(N_L);																\
	N_H = clamp01(N_H);																\
																					\
    float alpha = roughness * roughness;											\
    float alphaX = alpha * alpha;													\
    float t = (N_H * N_H) * (alphaX - 1.0) + 1.0;									\
    float d = INV_PI * alphaX / (t * t);											\
	intensity = N_L * d;															\
}

/**
 *	正規化２乗距離減衰
 */
#define calcFalloffNormalizedDist(ret, light, inv_r)				\
{																	\
	float dist_damp = clamp01(1.0 - sqrt(light.lit_dist2) * inv_r);	\
	ret = clamp01(dist_damp*dist_damp);								\
}

/**
 *	Unreal Engine 4 の減衰
 */
#define calcFalloffDist(ret, light, inv_r)									\
{																			\
	float numerator = light.dist_inv_r_sqr;									\
	float inv_ = 1.0/(light.lit_dist2 * light.inv_unit_scale_sqr + 1.0);	\
	numerator = clamp01(1.0 - numerator*numerator);							\
	ret = numerator * numerator * inv_;										\
}

/**
 *	ディフューズ反射。光源への角度によって単位面積あたりに受け取るエネルギーが変わる
 */
#define calcN_L(light, frag)						\
{													\
	light.N_L = clamp01(dot(frag.N, light.L));	\
}

/**
 *	スクリーン座標減衰を求める
 */
void calcScreenAttn(inout LightInfo light
					 , in float	inv_r
					 , in vec3	ray
					 , in vec3	sc_info) // xy : スクリーン座標, z : proj_w/R^2
{
	// スクリーン座標減衰
	// 描画範囲を活用するためにスクリーン座標での距離を使う
	vec2 ss_light_dir = ray.xy - sc_info.xy;
	// 距離の二乗
	float ss_light_dist_2 = DOT2_E(ss_light_dir, ss_light_dir);
	// sc_info.z には 1/sc_r^^2 が入っている
	light.specular_attn = clamp01(1.0 - (sqrt(ss_light_dist_2) * sc_info.z));
}

/**
 *	ディフューズ反射を計算する
 *	albedo.a が 1 ならディフューズ、0 なら金属やガラス
 */
vec3 calcDiffuseMetalToMatte(in vec4 albedo, in vec3 light)
{
	const float inv_pi = 1.0 / PI;
	return mix(vec3(0.0), albedo.rgb * light * inv_pi, albedo.a);
}

/**
 *	ディフューズの強さを計算する
 */
float calcDiffuseIntensity(in LightInfo light)
{
	return light.N_L * light.diffuse_attn * INV_PI;
}

/**
 *	ディレクショナルライトのディフューズの強さを計算する
 */
float calcDirectionalDiffuseIntensity(in LightInfo light)
{
	return light.N_L * INV_PI;
}

/**
 *	フレネル計算
 */
float calcFresnel(in float hFresnelN, in float V_H)
{
#if 1
	// Spherical Gaussian approximation Fresnel
	const float a1 = -5.55473;
	const float a2 = -6.98316;
	return hFresnelN + (1.0 - hFresnelN) * exp2((a1 * V_H + a2) * V_H);
#else
	// Disney's Fresnel
	float V_H2 = V_H*V_H;
	float V_H5 = V_H2*V_H2*V_H;
	return mix(hFresnelN, 1.0, V_H5);
#endif
}

#if 0
/// フレネル項の計算。n は屈折率
float calcFresnel(float n, float c)
{
	float g = sqrt(n*n + c*c - 1.0);
	float g_add_c = g+c;
	float g_sub_c = g-c;
	float T1 = (g_sub_c*g_sub_c) / (g_add_c*g_add_c);
	float T2 = 1.0 + ((c*g_add_c-1.0) * (c*g_add_c-1.0)) / ((c*g_sub_c+1.0)*(c*g_sub_c+1.0));
	return 0.5 * T1 * T2;
}
#endif

/**
 *	スフィアライトのディフューズ強さの計算
 */
float calcSphereLightDiffuseIntensity(in	FragInfo	frag
								   , inout	LightInfo	light
								   , in		vec3		pos_to_lit
								   , in		float		inv_r
								   , in		float		sphere_r)
{
	// 近傍点を求める。ディフューズ用
	// ライトからの相対位置
	{
		float len_2 = dot(pos_to_lit, pos_to_lit);
		float inv_len = inversesqrt(len_2);
		float back_step = clamp01(sphere_r * inv_len);
		// back_step が１のときはクランプされているので、シェーディングポイントに触れる可能性がある
		// なので法線方向に微小分だけ動かす。
		vec3 pos_to_closest = pos_to_lit - pos_to_lit * back_step + frag.N * uSphereLightDiffuseAdd * back_step * back_step;
		setLightToPos(light, -pos_to_closest, inv_r); // Mul Add
	}
	// 上記の L で N_L を計算しなおす
	calcN_L(light, frag);

	// ディフューズの減衰
	calcFalloffDist(light.diffuse_attn, light, inv_r);

	// ディフューズ計算
	return calcDiffuseIntensity(light);
}

/**
 *	レイとスフィアの最近傍を考慮してフラグメント位置から最近傍点へのベクトルを求める
 */
void calcPosToClosestSphere(out vec3 pos_to_closest, in vec3 pos_to_lit, in vec3 ray, in float sphere_r)
{
	vec3 Ls = pos_to_lit;
	vec3 center_to_ray = dot(Ls, ray) * ray - Ls;
	float len_2 = dot(center_to_ray, center_to_ray);
	float inv_len = inversesqrt(len_2);
	pos_to_closest = Ls + center_to_ray * clamp01(sphere_r * inv_len);
}

/**
 *	スフィアライトのスペキュラ強さの計算（GGX)
 */
vec3 calcSphereLightSpecularIntensityGGX(in	FragInfo	frag
										, inout	LightInfo	light
										, in	vec3		pos_to_lit
										, in	float		inv_r
										, in	float		sphere_r)
{
	// 最近傍点を求め、そこからのスペキュラを求める
	// この近傍点でポイントライトGGXを計算する
	vec3 pos_to_closest;
	calcPosToClosestSphere(pos_to_closest, pos_to_lit, frag.R, sphere_r);
	setLightToPos(light, -pos_to_closest, inv_r);

	// N_L を計算する
	calcN_L(light, frag);

	// スペキュラ計算
	calcN_H(frag, light);

	// スペキュラ減衰
	calcFalloffNormalizedDist(light.specular_attn, light, inv_r);

	// 資料にあったスフィアライトの正規化成分を計算
	calcSpecularGGXNormalization(frag, light, sphere_r);

	calcSpecularGGX(frag, light); // G と F も込みで計算

	return clamp01(light.spc_intensity * light.specular_attn);
}

/**
 *	スフィアライト計算 GGX
 */
vec3 calcSphereLight(in		FragInfo	frag
				   , inout	LightInfo	light
				   , in		PointLight	pt)
{
	vec3 pos_to_lit = pt.mVposInvR.xyz - frag.view_pos;

	// スフィアライトのディフューズ強さ計算
	float diffuse_intensity = calcSphereLightDiffuseIntensity(frag, light, pos_to_lit, pt.mVposInvR.w, pt.mColorSphR.a);
	vec3 color = frag.albedo_color.rgb * pt.mColorSphR.rgb * diffuse_intensity;

	// スフィアライトのスペキュラ強さ計算
	#if (LPP_ENABLE_SPECULAR == 1)
	{
		vec3 specular_intensity = calcSphereLightSpecularIntensityGGX(frag, light, pos_to_lit, pt.mVposInvR.w, pt.mColorSphR.a);
		color += specular_intensity * pt.mColorSphR.rgb;
	}
	#endif // LPP_ENABLE_SPECULAR
//	color = vec3(frag.view_pos.z);
	return color;
}

/**
 *	スポットライトの角度減衰
 */
float calcSpotLightAngleAttn(in  LightInfo	light
						   , in  SpotLight	spot)
{
	// 角度減衰
	float LD = dot(-light.L, spot.mVdirAngPow.xyz);
	// angle_attn_coef はいらないんじゃないか。無ければクラスタードシェーディングがシンプルになる。
	float angle_attn = clamp01(LD * spot.mAttn.x - spot.mAttn.y);
	return clamp01(pow(angle_attn, spot.mVdirAngPow.w)); //Cafeだとclampする必要がない、NXだとclampしないとブルームでぶっ壊れる
}

/**
 *	スポットライトのディフューズ部
 */
vec3 calcSpotLightDiffuse(out float		angle_attn
						, in  FragInfo	frag
						, in  LightInfo	light
						, in  SpotLight	spot)
{
	// 距離減衰は light.diffuse_attn
	angle_attn = calcSpotLightAngleAttn(light, spot);

	float intensity = calcDiffuseIntensity(light) * angle_attn;
	return frag.albedo_color.rgb * spot.mColorSphR.rgb * intensity;
}

/**
 *	スポットライトの計算
 */
vec3 calcSpotLight(in		FragInfo	frag
				 , inout	LightInfo	light
				 , in		SpotLight	spot)
{
	vec3 pos_to_lit = spot.mVposInvR.xyz - frag.view_pos;
	// 距離減衰は light.diffuse_attn
	// light.L とかは求まっている必要がある。
	// スフィアライトの影響を考える前に角度減衰を求める
	calcL(light, -pos_to_lit);
	float angle_attn = calcSpotLightAngleAttn(light, spot);

	// スフィアライトのディフューズ強さ計算
	float diffuse_intensity = calcSphereLightDiffuseIntensity(frag, light, pos_to_lit, spot.mVposInvR.w, spot.mColorSphR.a);

	vec3 color = frag.albedo_color.rgb * spot.mColorSphR.rgb * (diffuse_intensity * angle_attn);

	// スフィアライトのスペキュラ強さ計算
	#if (LPP_ENABLE_SPECULAR == 1)
	{
		vec3 specular_intensity = calcSphereLightSpecularIntensityGGX(frag, light, pos_to_lit, spot.mVposInvR.w, spot.mColorSphR.a);
		color += (specular_intensity * angle_attn) * spot.mColorSphR.rgb;
	//	color += calcSpecular(frag.base_color, lit_color, frag.metalness);
	}
	#endif // LPP_ENABLE_SPECULAR
	return color;
}

/**
 *	線分のうち、r との angle が最小になる点への t を求める
 */
float calcSmallestAngleSegmentPos(in vec3 r
								, in vec3 L0
								, in vec3 Ld)
{
	#if 1
	// Unreal Engine SIGGRAPH 2013
	//		dot(r, L0)dot(r, Ld) - dot(L0, Ld)
	//	t = ----------------------------------
	//			|Ld|^2 - dot(r, Ld)^2
	float r_Ld = dot(r, Ld);
	float numerator = dot(r, L0) * r_Ld - dot(L0, Ld); // 分子
	float denominator = dot(Ld, Ld) - r_Ld*r_Ld;
	float t_s = clamp01(numerator / denominator);
	#else
	// Picott
	//      (L0Ld)(rL0) - (L0L0)(rLd)
	// t = ----------------------------------
	//      (L0Ld)(rLd) - (LdLd)(rL0)
	float L0Ld = dot(L0, Ld);
	float rL0 = dot(r, L0);
	float L0L0 = dot(L0, L0);
	float rLd = dot(r, Ld);
	float LdLd = dot(Ld, Ld);
	float t_s = clamp01((L0Ld * rL0 - L0L0 * rLd)/(L0Ld * rLd - LdLd * rL0));
	#endif

	return t_s;
}

/**
 *	ラインライトの計算
 */
vec3 calcLineLight(in		FragInfo	frag
				 , inout	LightInfo	light
				 , in		LineLight	line)
{
	// 線分の一番近い点を求める
	vec3 bp = line.mVposInvR.xyz;
	vec3 Ld = line.mVpos2InvLen2.xyz - bp;
	
	vec3 begin_to_pos = frag.view_pos - bp;
	// 線分の一番近い点を求める
	float t1 = clamp01(dot(Ld, begin_to_pos) * line.mVpos2InvLen2.w);
	
	vec3 point_light_pos = bp + t1 * Ld;
	
	vec3 pos_to_lit = point_light_pos - frag.view_pos;
	// スフィアライトのディフューズ強さ計算
	float diffuse_intensity = calcSphereLightDiffuseIntensity(frag
															, light
															, pos_to_lit
															, line.mVposInvR.w
															, line.mColorSphR.a);
	vec3 color = frag.albedo_color.rgb * line.mColorSphR.rgb * diffuse_intensity;

	// スペキュラ計算
	#if (LPP_ENABLE_SPECULAR == 1)
	{
		vec3 L0 = bp - frag.view_pos;

		vec3 r = reflect(frag.view_pos, frag.N);
		NORMALIZE_EB(r, r);
		
		vec3 line_dir;
		NORMALIZE_EB(line_dir, Ld);
		// アングルが最小となる点を求める
		float t_s = calcSmallestAngleSegmentPos(r, L0, Ld);

		// 反射ベクトルがラインの向きに近い場合にアーティファクトが出るので対策
		float mix_rate = clamp01(abs(dot(r, line_dir))); // 垂直に近い場合は０に近づく
		#if 0
		{
			mix_rate = pow(mix_rate, uLineLightAntiArtifact);
		}
		#else
		{
			mix_rate = mix_rate*mix_rate;
			mix_rate = mix_rate*mix_rate;
			mix_rate = mix_rate*mix_rate;
		}
		#endif
		float t = mix(t_s, t1, mix_rate); // 最小アングルと近傍を角度で混ぜる
		point_light_pos = bp + t * Ld;

		pos_to_lit = point_light_pos - frag.view_pos;
		// スフィアライトのスペキュラ強さ計算
		vec3 specular_intensity = calcSphereLightSpecularIntensityGGX(frag, light, pos_to_lit, line.mVposInvR.w, line.mColorSphR.a);
		color += (specular_intensity) * line.mColorSphR.rgb;
	//	color += calcSpecular(frag.base_color, lit_color, frag.metalness);
	}
	#endif // LPP_ENABLE_SPECULAR
	return color;
}

#endif // AL_LIGHTING_FUNCTION_GLSL
