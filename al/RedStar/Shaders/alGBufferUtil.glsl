/**
 * @file	alGBufferUtil.glsl
 * @author	Yosuke Mori  (C)Nintendo
 *
 * @brief	Gバッファに関するユーティリティ
 */

#ifndef AL_G_BUFFER_UTIL_GLSL
#define AL_G_BUFFER_UTIL_GLSL

#define ENCODE_GBUF_NRM_TYPE	(1)
#define ENCODE_WORLD_NRM_SIGN	(0)
#define ENCODE_OCT_NRM_VEC		(1)


/**
 *	復元すべき G-Buffer の要素
 */
struct GBufferInfo
{
	vec3	normal;
	float	roughness;
	float	metalness;

#if (ENCODE_GBUF_NRM_TYPE == ENCODE_WORLD_NRM_SIGN)
	int		normal_sign;
#endif // ENCODE_GBUF_NRM_TYPE
};

/**
 *	法線 G-Buffer のエンコードデコード
 *	Octahedron-normal vectors
 */
vec2 OctWrap(vec2 v)
{
	return (1.0 - abs(v.yx))
			* vec2((v.x >= 0.0) ? +1.0 : -1.0
				 , (v.y >= 0.0) ? +1.0 : -1.0);
}

/**
 *	長さが１のベクトルを Octahedron-normal vector として vec2 にエンコード
 */
#define encodeVec3ToOctVec2(out_v2, v)					\
{														\
	vec2 p = v.xy / (abs(v.x) + abs(v.y) + abs(v.z));	\
	out_v2 = (v.z >= 0.0) ? p.xy : OctWrap(p.xy);		\
	out_v2 = out_v2 * 0.5 + 0.5;						\
}

/**
 *	Octahedron-normal vector を vec3 にデコード
 */
#define decodeOctVec2ToVec3(out_v3, v2)					\
{														\
	vec2 v_ = v2 * 2.0 - 1.0;							\
	vec3 v;												\
	v.z = 1.0 - abs(v_.x) - abs(v_.y);					\
	v.xy = (v.z >= 0.0) ? v_.xy : OctWrap(v_.xy);		\
	out_v3 = normalize(v);								\
}


#if (ENCODE_GBUF_NRM_TYPE == ENCODE_WORLD_NRM_SIGN)

	#define encodeWorldNrm(out_v2, nrm)			\
	{											\
		out_v2.xy = nrm.xy * 0.5 + vec2(0.5);	\
	}

	#define decodeWorldNrm(g_buf, tex, coord)									\
	{																			\
		g_buf.normal.xy = texture(tex, coord).rg;								\
		g_buf.normal.xy = g_buf.normal.xy * 2.0 - vec2(1.0);					\
		g_buf.normal.z  = 1.0 - dot(g_buf.normal.xy, g_buf.normal.xy);			\
		g_buf.normal.z  = g_buf.normal_sign * sqrt(clamp01(g_buf.normal.z));	\
	}

#elif (ENCODE_GBUF_NRM_TYPE == ENCODE_OCT_NRM_VEC)

	#define encodeWorldNrm(out_v2, nrm)			\
	{											\
		encodeVec3ToOctVec2(out_v2.xy, nrm);	\
	}

	#define decodeWorldNrm(g_buf, tex, coord)			\
	{																\
		decodeOctVec2ToVec3(g_buf.normal.xyz, texture(tex, coord).rg);	\
	}
#endif // ENCODE_GBUF_NRM_TYPE


#if (ENCODE_GBUF_NRM_TYPE == ENCODE_WORLD_NRM_SIGN)

#define ALL_BIT_SIZE			(8u)
#define ROUGHNESS_BIT_SIZE		(4u)
#define METALNESS_BIT_SIZE		(3u)
#define NORMALZ_BIT_SIZE		(1u)
#define ROUGHNESS_MAX			((1u << ROUGHNESS_BIT_SIZE) - 1u)
#define METALNESS_MAX			((1u << METALNESS_BIT_SIZE) - 1u)
#define ROUGHNESS_BIT_MASK		(ROUGHNESS_MAX << (METALNESS_BIT_SIZE + NORMALZ_BIT_SIZE))
#define METALNESS_BIT_MASK		(METALNESS_MAX << NORMALZ_BIT_SIZE)

	// ラフネス(4)|メタルネス(3)|ノーマルZの符号(1)をパッキング
	#define  encodeGBufferBaseColor(output, base_color, roughness, metalness, normal) \
	{ \
		float normal_sign = step(0.0, normal.z); \
		uint pack = 0u; \
		uint roughness_bit	= uint(roughness * ROUGHNESS_MAX); \
		uint metalness_bit	= uint(metalness * METALNESS_MAX); \
		uint nrm_sign_bit	= uint(normal_sign); \
		pack |= roughness_bit << (ALL_BIT_SIZE - ROUGHNESS_BIT_SIZE); \
		pack |= metalness_bit << (ALL_BIT_SIZE - ROUGHNESS_BIT_SIZE - METALNESS_BIT_SIZE); \
		pack |= nrm_sign_bit; \
		output = vec4(base_color, float(pack) / 255.0);	\
	}

	// ラフネス(4)|メタルネス(3)|ノーマルZの符号(1)を取り出す
	// @note マクロ内で0xがあるとglslパーサがエラーを吐くので関数化した
	#define decodeGBufferBaseColor(g_buf, base_color_a) \
	{ \
		uint pack = uint(base_color_a * 255); \
		g_buf.roughness = float((pack & ROUGHNESS_BIT_MASK) >> (METALNESS_BIT_SIZE + NORMALZ_BIT_SIZE)) / float(ROUGHNESS_MAX); \
		g_buf.metalness = float((pack & METALNESS_BIT_MASK) >> (NORMALZ_BIT_SIZE)) / float(METALNESS_MAX); \
		g_buf.normal_sign = int(pack & 1u); \
		g_buf.normal_sign = g_buf.normal_sign * 2 - 1; \
	}

#elif (ENCODE_GBUF_NRM_TYPE == ENCODE_OCT_NRM_VEC)

#define ALL_BIT_SIZE			(8u)
#define ROUGHNESS_BIT_SIZE		(4u)
#define METALNESS_BIT_SIZE		(4u)
#define ROUGHNESS_MAX			((1u << ROUGHNESS_BIT_SIZE) - 1u)
#define METALNESS_MAX			((1u << METALNESS_BIT_SIZE) - 1u)
#define ROUGHNESS_BIT_MASK		(ROUGHNESS_MAX << METALNESS_BIT_SIZE)
#define METALNESS_BIT_MASK		(METALNESS_MAX)

	// ラフネス(4)|メタルネス(4)をパッキング
	#define  encodeGBufferBaseColor(output, base_color, roughness, metalness, normal) \
	{ \
		uint pack = 0u; \
		uint roughness_bit = uint(roughness * ROUGHNESS_MAX); \
		uint metalness_bit = uint(metalness * METALNESS_MAX); \
		pack |= roughness_bit << METALNESS_BIT_SIZE; \
		pack |= metalness_bit; \
		output = vec4(base_color, float(pack) / 255.0);	\
	}

	// ラフネス(4)|メタルネス(4)を取り出す
	// @note マクロ内で0xがあるとglslパーサがエラーを吐くので関数化した
	#define decodeGBufferBaseColor(g_buf, base_color_a) \
	{ \
		uint pack = uint(base_color_a * 255); \
		g_buf.roughness = float((pack & ROUGHNESS_BIT_MASK) >> METALNESS_BIT_SIZE) / float(ROUGHNESS_MAX);\
		g_buf.metalness = float(pack & METALNESS_BIT_MASK) / float(METALNESS_MAX); \
	}
#endif // ENCODE_GBUF_NRM_TYPE

#ifdef IMPORT_LIGHTING_FUNCTION

/**
 *	ベースカラー G-Buffer から情報を取り出す
 */
#define storeFragInfoByBaseColorGBuffer(frag, g_buf, sampler, texcrd) \
{ \
	vec4 base = texture2D(sampler, texcrd); \
	decodeGBufferBaseColor(g_buf, base.a); \
	setMaterialParam(frag, base.rgb, g_buf.roughness, g_buf.metalness); \
}

#endif // IMPORT_LIGHTING_FUNCTION

/**
 *	G-Bufferフェッチ時のUV計算
 */
#define toGBufScreenUv(uv, offset, scale) \
{ \
	uv = 0.5 * uv + 0.5; \
	uv.y = 1.0 - uv.y; \
	if (ENABLE_GBUF_FETCH_OFFSET == 1) \
	{ \
		uv.x += offset * scale; \
		uv.y += offset * scale; \
	} \
}

#endif // AL_G_BUFFER_UTIL_GLSL
