/**
 * @file	alCloudParticleUtil.glsl
 * @author	Matsuda Hirokazu  (C)Nintendo
 *
 * @brief	パーティクルによる雲レンダリングユーティリティ
 */

#ifndef CLOUD_PARTICLE_UTIL_GLSL
#define CLOUD_PARTICLE_UTIL_GLSL

#include "alDeclareUniformBlockBinding.glsl"
#include "alGpuRandom.glsl"

/**
 *	パーティクル雲レンダリングで使う Ubo
 */
BINDING_UBO_OTHER_FIRST uniform CloudParticleUbo
{
	vec4	uWorldMtx[3];		// 雲パーティクルのワールド行列
	vec4	uData;				// xyz : local range,  w : gauss distribution scale
	vec4 	uParticleProperty;	// x : extinction σ,  y : size min,  z : size max,  w : なぜか透視投影だとサイズが変なのでスケール掛けてみる
	vec4 	uScatterParam;		// x : k of forward scatter,  y : k of back scatter,  z : forward - back mix rate
};

#define LOCAL_RANGE_SCALE 			uData.xyz
#define DISTRIB_SCALE				uData.w
#define EXTINCTION					uParticleProperty.x
#define SIZE_MIN					uParticleProperty.y
#define SIZE_MAX					uParticleProperty.z
#define PERS_PARTICLE_SCALE			uParticleProperty.w

#define CLOUD_KF					uScatterParam.x
#define CLOUD_KB					uScatterParam.y
#define CLOUD_KF_KB_MIX				uScatterParam.z

/**
 *	パーティクルでの雲表現をする際の構造体
 */
struct CloudParticle
{
	vec3 	local_pos;
	float	size;
	float	intensity;
};

/**
 *	クラウドパーティクルの初期化
 */
#define initCloudParticle(pt)		\
{									\
	pt.local_pos = vec3(0);			\
	pt.size = 1.0;					\
	pt.intensity = 1.0;				\
}

/**
 *	雲パーティクルの情報を vertex id と乱数から求める。
 *	[-1, +1] の範囲に分布させる
 */
void calcCloudParticleInfo(out CloudParticle pt, in uint vtx_id)
{
	uint seed = calcHashWang(vtx_id);
	pt.size = mix(SIZE_MIN, SIZE_MAX, calcGpuRandomXorshift(seed));
	// 三つの乱数で三つの正規分布乱数を作ったら偏ったので六つ作る
	float u1 = calcGpuRandomXorshift(seed);
	float u2 = calcGpuRandomXorshift(seed);
	#if 1
	float u3 = calcGpuRandomXorshift(seed);
	float u4 = calcGpuRandomXorshift(seed);
	float u5 = calcGpuRandomXorshift(seed);
	float u6 = calcGpuRandomXorshift(seed);
	pt.local_pos.x = clamp(makeGpuRandomGauss(u1, u2)*DISTRIB_SCALE, -1, 1);
	pt.local_pos.y = clamp(makeGpuRandomGauss(u3, u4)*DISTRIB_SCALE, -1, 1);
	pt.local_pos.z = clamp(makeGpuRandomGauss(u5, u6)*DISTRIB_SCALE, -1, 1);
	#else
	// 球面上にとってみる
	calcSpherePointPicking(pt.local_pos, u1, u2);
	#endif
	pt.local_pos *= LOCAL_RANGE_SCALE; // [-LOCAL_RANGE_SCALE, LOCAL_RANGE_SCALE] の範囲になる
}

/**
 *	ポイントスプライトを円形にする
 */
void calcCloudParticleCircle(out float shape, in vec2 pt_crd)
{
#if 0
	// gl_PointCoord = [0, 1]
	vec2 center_origin = pt_crd * 2 - 1;
	shape = 1.0 - clamp01(dot(center_origin, center_origin));
#elif 1
	// Ease In Ease Out
	vec2 center_origin = pt_crd * 2 - 1;
	float len_sqr = clamp01(dot(center_origin, center_origin));
	shape = 1.0 - (3.0f-2.0f*len_sqr)*len_sqr*len_sqr;
#elif 0
	// 栗原式。上とほぼ同じ
	vec2 dif = pt_crd - vec2(0.5, 0.5);
	float dist2 = (dif.x * dif.x) + (dif.y * dif.y);
	shape = (clamp01(1.0 - dist2 * 4.0));// 円周で0になるよう距離減衰
#else
	// 栗原式
	vec2 dif = pt_crd - vec2(0.5, 0.5);
	float dist2 = (dif.x * dif.x) + (dif.y * dif.y);
	float dist = sqrt(dist2);
//	if(dist > 0.5) discard;
	float scale = (dist > 0.5) ? 0.0 : 1.0; // discard は使えないのでスケールで。
	dist = dist * 2;
	shape = scale*((8 * dist*dist*dist - 9 * dist*dist + 1)*0.5+0.5);
#endif
}

// ポイントスプライトの大きさを決める
#define CalcPointSize(pt)	(pt.size * InvNearClipWidth * ScrSizeX / gl_Position.w)

/**
 *	ポイントスプライトの各フラグメントにて clip space の座標を求める
 *	gl_FragCoord を使う
 *	以下を参考にやってもうまくいかなかった。
 *	gl_FragCoord から clip space を求めてビュー位置を求める
 *	https://www.opengl.org/wiki/Compute_eye_space_from_window_space#From_gl_FragCoord
 *	http://tokyoweb/TokyoProgrammer/wiki/wiki.cgi?page=%B5%BB%BD%D1%A5%E1%A5%E2%2F%A5%D7%A5%ED%A5%B8%A5%A7%A5%AF%A5%B7%A5%E7%A5%F3
 */
void calcClipPositionFromFragCoord(out vec4 clip_pos, in vec2 inv_screen_size)
{
	// gl_FragCoord.z は w で割った後の正規化デバイス座標系の z を 0.5*ndc.z + 0.5 したもの
	// つまり ndc.z = (gl_FragCoord.z - 0.5)/0.5 = 2 * gl_FragCoord.z - 1;
	float ndc_z = 2 * gl_FragCoord.z - 1; 	// OpenGL
//	float ndc_z = gl_FragCoord.z;			// DirectX

	// まずビューポート変換を戻す
	clip_pos.xy = gl_FragCoord.xy * inv_screen_size * 2 - 1; // [0, 0] - [width, height] -> [0, 0] - [-1, 1] に変換
	clip_pos.y = -clip_pos.y; // 反転するケース
	clip_pos.w = 1.0;
	clip_pos.z = ndc_z; // これでいいっぽい

	// 以下、うまくいかなかった処理
//	clip_pos.w = 1.0/gl_FragCoord.w; // ネットの記事を見てこっちかと思ったが違った。
//	clip_pos.z = ndc_z/gl_FragCoord.w; // gl_FragCoord.z は w で割った後の z なので戻す...とうまくいかない！
}

#endif // CLOUD_PARTICLE_UTIL_GLSL
