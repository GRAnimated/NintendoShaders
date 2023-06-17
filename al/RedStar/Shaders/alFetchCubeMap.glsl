/**
 * @file	alFetchCubeMap.glsl
 * @author	Yosuke Mori  (C)Nintendo
 *
 * @brief	キューブマップフェッチ関数
 */

/**
 * キューブマップ配列のキューブマップカラーを取得する
 */
#define fetchCubeMapArray(fetch, sampler, dir)								\
{																				\
	vec4 cube_ = texture((sampler), vec4((dir).x, (dir).y, -(dir).z, dir.w));	\
	(fetch).rgb = cube_.rgb;													\
}

/**
 *	パララックスコレクトキューブマップ方向計算
 * 	vec3 first_plane_intersect = (unitary - pos_l) * inv_reflectl;					\
	vec3 second_plane_intersect = (-unitary - pos_l) * inv_reflectl;				\
	vec3 pos_w = multMtx34Vec4(cInvView, vec4(pos_v, 1.0)).xyz;
 */
#define	calcParallaxCubeMapDir(fetch_dir, pos_w, reflect_w)							\
{																					\
	vec3 reflect_l = rotMtx33Vec3(cParallaxCubeInvWorldMtx, reflect_w); 			\
																					\
	vec3 unitary = cParallaxCubeHalfSize;											\
	vec3 inv_reflectl = 1.0 / reflect_l;											\
	vec3 unitary_inv_reflectl = unitary * inv_reflectl;								\
	vec3 pos_l = multMtx34Vec4(cParallaxCubeInvWorldMtx, vec4(pos_w, 1.0)).xyz;		\
	vec3 posl_inv_reflectl = pos_l * inv_reflectl;									\
	vec3 first_plane_intersect = unitary_inv_reflectl - posl_inv_reflectl;			\
	vec3 second_plane_intersect = -unitary_inv_reflectl - posl_inv_reflectl;		\
	vec3 furthest_plane = abs(max(first_plane_intersect, second_plane_intersect));	\
																					\
	float dist = min(furthest_plane.x, min(furthest_plane.y, furthest_plane.z));	\
	NORMALIZE_B(fetch_dir, pos_w + reflect_w * dist - cParallaxCubeCenter); \
}

/**
 *	キューブマップフェッチ Lod 版
 *	dir は左手座標系に。
 */
#define	fetchCubeMapLod(fetch, sampler, dir, bias)										\
{																						\
	(fetch).rgb = textureLod((sampler), vec3((dir).x, (dir).y, -(dir).z), bias).rgb;	\
}

/**
 *	キューブマップフェッチ
 *	dir は左手座標系に。
 */
#define	fetchCubeMapNoBias(fetch, sampler, dir)							\
{																		\
	vec4 _cube = texture((sampler), vec3((dir).x, (dir).y, -(dir).z));	\
	(fetch).rgb = _cube.rgb;											\
}

/**
 *	キューブマップフェッチ
 *	bias 指定
 *	dir は左手座標系に。
 */
#define	fetchCubeMap(fetch, sampler, dir, bias)												\
{																							\
	if (IS_USE_TEXTURE_BIAS == 1)															\
	{																						\
		(fetch).rgb = texture((sampler), vec3((dir).x, (dir).y, -(dir).z), bias).rgb;		\
	}																						\
	else																					\
	{																						\
        fetchCubeMapLod(fetch, sampler, dir, bias);                                         \
	}																						\
}

/**
 *	キューブマップフェッチ(HDR化)
 *	bias 指定
 *	dir は左手座標系に。
 */
#define	fetchCubeMapConvertHdr(fetch, sampler, dir, bias)						\
{																				\
	vec4 cube_;																	\
	if (IS_USE_TEXTURE_BIAS == 1)												\
	{																			\
		cube_ = texture((sampler), vec3((dir).x, (dir).y, -(dir).z), bias);		\
	}																			\
	else																		\
	{																			\
		cube_ = textureLod((sampler), vec3((dir).x, (dir).y, -(dir).z), bias);	\
	}																			\
	CalcLdrToHdr(fetch, cube_);													\
}

/**
 *	イラディアンス用キューブマップフェッチ
 *	dir は左手座標系に。
 */
#define	fetchCubeMapIrradiance(fetch, sampler, dir)		\
{														\
	(fetch).rgb = textureLod((sampler), vec3((dir).x, (dir).y, -(dir).z), 5).rgb; \
}

/**
 *	イラディアンス用キューブマップフェッチ(HDR化してスケールも .a に格納)
 *	dir は左手座標系に。
 */
#define	fetchCubeMapIrradianceConvertHdr(fetch, sampler, dir)				\
{																			\
	vec4 cube_;																\
	cube_ = textureLod((sampler), vec3((dir).x, (dir).y, -(dir).z), 5);		\
	CalcLdrToHdr(fetch, cube_);												\
}

/**
 *	イラディアンス用キューブマップスケールありフェッチ
 *	dir は左手座標系に。
 */
#define	fetchCubeMapIrradianceScale(fetch, sampler, dir)	\
{															\
	fetchCubeMapIrradiance(fetch, sampler, dir);			\
	(fetch).rgb *= uIrradianceScale;						\
}

/**
 *	イラディアンス用キューブマップスケールありフェッチ(HDR化)
 *	dir は左手座標系に。
 */
#define	fetchCubeMapIrradianceScaleConvertHdr(fetch, sampler, dir) \
{																	\
	fetchCubeMapIrradianceConvertHdr((fetch), sampler, dir);		\
	(fetch).rgba *= uIrradianceScale;								\
}
