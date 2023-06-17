/**
 * @file	alHdrUtil.glsl
 * @author	Matsuda Hirokazu  (C)Nintendo
 *
 * @brief	HDR <-> LDR 変換など
 */
#ifndef AL_HDR_UTIL
#define AL_HDR_UTIL

BINDING_UBO_HDR_TRANSLATE uniform HDRTranslate // @@ id="cHdrTranslate"
{
	float	uHDRPower;
	float	uDynamicRange;
};

#define ENCODE_BASE	0.25

/**
 *	base : 0.25 の倍数に繰り上げる
 */
#define	CalcHdrToLdr(ldr, hdr)													\
{																				\
	float head_value = max(max(hdr.r, hdr.g), hdr.b);							\
	const float base_rcp = 1.0 / ENCODE_BASE;									\
	head_value += fract( 1.0 - ( head_value * base_rcp ) ) * ENCODE_BASE;		\
	head_value  = max( head_value, 1.0 / 256.0 );								\
	float texel_correct_value = clamp01( head_value / uDynamicRange );			\
	texel_correct_value = pow( texel_correct_value, 1.0 / uHDRPower );			\
	ldr.rgb = hdr.rgb / head_value;												\
	ldr.a = texel_correct_value;												\
}

#define CalcLdrToHdr(hdr, ldr)								\
{															\
	float scale = pow(ldr.a, uHDRPower) * uDynamicRange;	\
	(hdr).rgba = vec4(ldr.rgb * scale, scale);				\
}

#endif // AL_HDR_UTIL
 
