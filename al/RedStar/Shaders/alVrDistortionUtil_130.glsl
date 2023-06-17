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
 *  uDistortionYScale : x : scale,  y : scale base,  z : 減光スケール,  w : tex coord scale base
 *	uBlackRadius : これより外側を黒くして酔い対策  x : Black Radius,  y : Black Radius Smooth Width,  z : 画面解像度
 *	uImageCircleFitUvOffset : x : イメージサークル半径[mm],  y : イメージサークルフィット距離[mm],  zw : uv offset
 *	uReprojectionParam : x : atan(fovx/2),  y : atan(fovy/2),  z : 1/atan(fovx/2),  w : 1/atan(fovy/2)
 *	cReprojectionMtx : 前回のビュー行列に掛け算すると最新のビュー行列になる行列。 post_view * inv(prev_view)
 *					   このマトリックスのために視点ごとに用意する
 */
layout(std140) uniform DistortionUbo
{
	vec4	uDistortionYScale;
	vec4	uBlackRadius;
	vec4	uImageCircleFitUvOffset;
	vec4	cReprojectionParam;
	vec4	cReprojectionMtx[3];
	// 範囲制限メッシュ用
	vec2	uFarPolyNum;	// x : far, y : poly num (float)
};

#define BLACK_R				(uBlackRadius.x)
#define BLACK_SMOOTH_W		(uBlackRadius.y)
#define UV_OFFSET			(uImageCircleFitUvOffset.zw)

#if 0
#define IMG_CIRCLE_R_MM		(36.050)
#define IMG_CIRCLE_FIT_MM	(46.996)
#elif 1
#define IMG_CIRCLE_R_MM		(uImageCircleFitUvOffset.x)
#define IMG_CIRCLE_FIT_MM	(uImageCircleFitUvOffset.y)
#elif 0
#define IMG_CIRCLE_R_MM		(uImageCircleFitUvOffset.x)
#define IMG_CIRCLE_FIT_MM	(46.996)
#else
#define IMG_CIRCLE_R_MM		(36.050)
#define IMG_CIRCLE_FIT_MM	(uImageCircleFitUvOffset.y)
#endif


#define calcDistortionVs(out_pos, out_texcrd, out_distortion_info, in_pos, in_texcrd) calcDistortionVsCore(out_pos, out_texcrd, out_distortion_info, in_pos, in_texcrd, uDistortionYScale, cReprojectionParam, cReprojectionMtx)
#define applyDistortionVignette(color, RI, dist) 	applyDistortionVignetteCore(color, RI, dist)

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

	vec2 rep_in_texcrd = in_texcrd;
	#if (USE_DISTORTION_REPROJECTION == 1)
	{
		vec3 pos = vec3((in_texcrd * vec2(2.0, -2.0) - vec2(1.0, -1.0)) * reproj_param.xy, 1.0);
		vec3 rp_pos;
		rp_pos.x = dot(reproj_mtx[0].xyz, pos);
		rp_pos.y = dot(reproj_mtx[1].xyz, pos);
		rp_pos.z = dot(reproj_mtx[2].xyz, pos);
		rp_pos.xy /= rp_pos.z;
		rep_in_texcrd = rp_pos.xy * reproj_param.zw * vec2(0.5,-0.5) + vec2(0.5);
	}
	#endif // (USE_DISTORTION_REPROJECTION == 1)

	out_texcrd = rep_in_texcrd;
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
	vec2 center_dist = 2.0 * in_texcrd - vec2(1.0); // リプロジェクション前のテクスチャ座標を使わないと黒い部分も動いてしまう
	out_distortion_info.z = dot(center_dist, center_dist);
}

/**
 *  フラグメントシェーダ用減光適用
 */
void applyDistortionVignetteCore(inout vec3 color, in float RI, in float center_dist_01)
{
	float vignette = RI;
	// 周辺を暗くして酔い対策に使う
	vignette *= 1.0 - smoothstep(BLACK_R - BLACK_SMOOTH_W, BLACK_R, center_dist_01);
	color.rgb *= vignette;
}

/**
 *	液晶上の距離 [mm] を渡すとディストーションさせた距離 [mm] を計算する関数
 */
float calcDistortionValueG_Fs(in float r_mm)
{
	// レンズパラメータ
//	const vec4 K = vec4( 9.9978E-01, -1.4123E-04,  2.0447E-08, -1.9046E-12); // バレルディストーション
	// ピンクッションディストーション
	const vec4 K = vec4(9.980970e-01, 1.618750e-04, -1.009378e-08, 5.068816e-11);
	const float r_mm2 = r_mm*r_mm;
	// *𝑟_𝑛𝑒𝑤 = 𝑟(𝑘_0 + 𝑘_1*𝑟^2 + 𝑘_2*𝑟^4 + 𝑘_3*𝑟^6)
	// ホーナー法で求める
	float ret = K[3];
	ret = K[2] + ret * r_mm2;
	ret = K[1] + ret * r_mm2;
	ret = K[0] + ret * r_mm2;
	ret *= r_mm; // 最後に r を掛けるのを忘れずに。
	return ret;
}

/**
 *	レンズの明るさ補正
 */
float calcRelativeIllumination_Fs(in float r_mm)
{
	const float r_mm2 = r_mm*r_mm;
	#if 0
	// Vertex Shader 用
	const vec4 RI = vec4(-2.7954E-03, -8.6579E-06,	1.6165E-09,	 2.2503E-12);
	// *𝑟_𝑛𝑒𝑤 = 𝑟(𝑘_0 + 𝑘_1*𝑟^2 + 𝑘_2*𝑟^4 + 𝑘_3*𝑟^6)
	// ホーナー法で求める
	float ret = RI[3];
	ret = RI[2] + ret * r_mm2;
	ret = RI[1] + ret * r_mm2;
	ret = RI[0] + ret * r_mm2;
	ret *= r_mm; // 最後に r を掛けるのを忘れずに。
	return 1.0 - ret;
	#else
	// フラグメントシェーダ用
	const float RI[] = {3.194537e-04, -6.077353e-08, 3.896990e-11, -5.864371e-14};
	// 1.0 + k0 * x**2 + k1 * x**4 + k2 * x**6 + k3 * x**8
	float ret = RI[3];
	ret = RI[2] + ret * r_mm2;
	ret = RI[1] + ret * r_mm2;
	ret = RI[0] + ret * r_mm2;
	ret = 1.0 + ret * r_mm2;
	return ret;
	#endif
}

/**
 *	色収差を G から求める
 */
void calcChromaticAberration(out vec3 ret, in float r_mm, in float r_mm_new_G)
{
	// レンズパラメータ
	const vec4 C  = vec4( 1.0020E+00,  4.7392E-07,  9.9509E-01, -8.6392E-07);
	const float r_mm2 = r_mm*r_mm;
	ret = vec3(r_mm_new_G*(C[0]+C[1]*r_mm2), r_mm_new_G, r_mm_new_G*(C[2]+C[3]*r_mm2));
}

// 実際の液晶の画面サイズ。単位は mm 縦横のサイズ（単位はmm）は 137.0880000000, 77.1120000000
#define	cDisplayW_mm	(137.088)
#define cDisplayW_pixel	(1280.0)
#define cMmToPixel 		(cDisplayW_pixel / cDisplayW_mm)
#define cPixelToMm 		(cDisplayW_mm / cDisplayW_pixel)

/**
 *	スイッチ液晶上の距離 mm と pixels の相互変換
 */
#define calcMmToPixels(mm)		(mm * cMmToPixel)
#define calcPixelsToMm(pixels)	(pixels * cPixelToMm)

#define calcDistortedUv_Fs(RI, uv_01)											\
{																				\
	vec2 uv_01_center_rel = uv_01 * 2.0 - vec2(1.0);							\
	float center_dist_01 = length(uv_01_center_rel);							\
	if (1.0 < center_dist_01) { discard; }										\
	vec2 uv_mm_center_rel = uv_01_center_rel * IMG_CIRCLE_R_MM;					\
	float r_mm = length(uv_mm_center_rel);										\
	float r_new_mm = calcDistortionValueG_Fs(r_mm);								\
	float r_new_01 = r_new_mm/IMG_CIRCLE_FIT_MM;								\
	vec2 distorted_uv_01_center_rel = normalize(uv_01_center_rel) * r_new_01;	\
	uv_01 = distorted_uv_01_center_rel * 0.5 + 0.5;								\
	RI = calcRelativeIllumination_Fs(r_mm);										\
	RI *= 1.0 - smoothstep(BLACK_R - BLACK_SMOOTH_W, BLACK_R, center_dist_01);	\
}

#endif // AL_VR_DISTORTIOIN_UTIL_GLSL
