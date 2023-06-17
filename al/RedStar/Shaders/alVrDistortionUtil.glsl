/**
 *  @file   alVrDistortionUtil.glsl
 *  @author Matsuda Hirokazu  (C)Nintendo
 *
 *  @brief  ディストーション用ユーティリティ
 */
#ifndef AL_VR_DISTORTIOIN_UTIL_GLSL
#define AL_VR_DISTORTIOIN_UTIL_GLSL

#ifndef USE_DISTORTION_REPROJECTION
	#define USE_DISTORTION_REPROJECTION 1
#endif // USE_DISTORTION_REPROJECTION

/**
 *  ディストーション用 Ubo の定義
 *  x : scale,  y : scale base,  z : 減光スケール,  w : tex coord scale base
 *	uBlackRadius : これより外側を黒くして酔い対策
 *	uReprojectionParam : x : atan(fovx/2),  y : atan(fovy/2),  z : 1/atan(fovx/2),  w : 1/atan(fovy/2)
 *	cReprojectionMtx : 前回のビュー行列に掛け算すると最新のビュー行列になる行列。 post_view * inv(prev_view)
 *					   このマトリックスのために視点ごとに用意する
 */
#define DECLARE_DISTORTION_UBO(bind)	\
layout(std140, binding = bind)			\
uniform DistortionUbo					\
{										\
	vec4	uDistortionYScale;			\
	vec2 	uBlackRadius;				\
	vec4	cReprojectionParam;			\
	vec4	cReprojectionMtx[3];		\
}										

#define calcDistortionVs(out_pos, out_texcrd, out_distortion_info, in_pos, in_texcrd) calcDistortionVsCore(out_pos, out_texcrd, out_distortion_info, in_pos, in_texcrd, uDistortionYScale, cReprojectionParam, cReprojectionMtx)
#define applyDistortionVignette(color, distortion_info) 	applyDistortionVignetteCore(color, distortion_info, uBlackRadius)

/**
 *  頂点シェーダで計算するディストーション情報
 */
void calcDistortionVsCore(out vec4 out_pos
						, out vec2 out_texcrd
						, out vec4 out_distortion_info
						, in vec4 in_pos
						, in vec2 in_texcrd
						, in vec4 dist_ubo
						, in vec4 reproj_param
						, in vec4 reproj_mtx[3]
						)
{
	out_distortion_info.xy = in_pos.zw;
	out_pos.xy = in_pos.xy;
	// 瞬きエフェクトのためのスケール
	// [-0.5, 0.5] にする
	float pos_ = out_pos.y - dist_ubo.y;
	// スケール掛けて範囲を戻す
	pos_ = pos_ * dist_ubo.x + dist_ubo.y;

	#if (USE_DISTORTION_REPROJECTION == 1)
	{
		vec3 pos = vec3((in_texcrd * vec2(2.0, -2.0) - vec2(1.0, -1.0)) * reproj_param.xy, 1.0);
		vec3 rp_pos;
		rp_pos.x = dot(reproj_mtx[0].xyz, pos);
		rp_pos.y = dot(reproj_mtx[1].xyz, pos);
		rp_pos.z = dot(reproj_mtx[2].xyz, pos);
		rp_pos.xy /= rp_pos.z;
		in_texcrd = rp_pos.xy * reproj_param.zw * vec2(0.5,-0.5) + vec2(0.5);
	}
	#endif // (USE_DISTORTION_REPROJECTION == 1)

	out_texcrd = in_texcrd;
	#if 1
	out_texcrd.y = out_texcrd.y + dist_ubo.w;
	out_texcrd.y = out_texcrd.y * dist_ubo.x - dist_ubo.w;
	#else
	// テクスチャ座標はディストーションメッシュの歪み量だけ移動
	out_texcrd.y += out_pos.y - pos_;
	#endif // 0

	out_pos.y = pos_;
	// 暗くもする
	out_distortion_info.y *= dist_ubo.z;

	// 中心からの距離を入れて周辺を暗くするのに使う
	vec2 center_dist = in_texcrd - vec2(0.5);
	out_distortion_info.z = dot(center_dist, center_dist);
}

/**
 *  フラグメントシェーダ用減光適用
 */
void applyDistortionVignetteCore(inout vec3 color, in vec4 distortion_info, in vec2 black_radius)
{
	// x にはタイムワープ用、y には減光値が入っている
	float vignette = distortion_info.y;
	// 周辺を暗くして酔い対策に使う
	vignette *= 1.0 - smoothstep(black_radius.x, black_radius.x+black_radius.y, distortion_info.z);
	color.rgb *= vignette;
}

#endif // AL_VR_DISTORTIOIN_UTIL_GLSL
