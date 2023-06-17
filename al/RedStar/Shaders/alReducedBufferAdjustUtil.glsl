/**
 * @file	alReducedBufferAdjustUtil.glsl
 * @author	Matsuda Hirokazu  (C)Nintendo
 *
 * @brief	縮小バッファのぴったりくん Util
 */
#ifndef AL_REDUCED_BUFFER_ADJUST_UTIL_GLSL
#define AL_REDUCED_BUFFER_ADJUST_UTIL_GLSL

#include "alDefineVarying.glsl"

// Uniform ０を使う
uniform vec2  uReducedBufferTexel;
uniform vec2  uReducedBufferTexelSizeInv;
uniform float uReducedBufferDepthCoeff;


DECLARE_VARYING(vec2,	vHalfBufferTexelCoord);
DECLARE_VARYING(vec2,	vHalfBufferTexelCoordOffset);

#if defined(AGL_VERTEX_SHADER)
/**
 *	テクセル座標の準備を頂点シェーダで行う
 */
void calcTexCoordReducedBufferAdjust(in vec2 tex_crd)
{
    // 0.25, 0.75, 1.25, 1.75...というテクセル座標を
    // 0.00, 0.50, 1.00, 1.50...というテクセル座標に変換して小数部を使う
    vHalfBufferTexelCoord  = uReducedBufferTexel * tex_crd + vec2(0.5);
   // 最後に戻す値も計算しておく
    vHalfBufferTexelCoordOffset = -uReducedBufferTexelSizeInv * vec2(0.5);
}
#endif // AGL_VERTEX_SHADER

void calcReducedBufferAdjustUV(out vec2 uv
							 , in float full_depth_
							 , in sampler2D half_view_depth
							 , in vec2 tex_coord
							 , in float near
							 , in float inv_range
							 )
{
	vec4 full_depth = vec4(full_depth_);
	vec4 half_depth = textureGather(half_view_depth, tex_coord);

	// 1/2縮小で計算されたデプスと今のピクセルデプスの差の絶対値
	vec4 diff = abs(half_depth - full_depth);
	vec2 frac_texel = fract(getVarying(vHalfBufferTexelCoord));
	vec2 f = frac_texel * 2.0 - 0.5;

	// [0.25,0.75] -> [0.0,1.0]
	float fxy = f.x * f.y;
	vec4 w03 = vec4(2.0, -1.0,  0.0, -1.0) + vec4(2.0, -2.0,  2.0, -2.0) * fxy;
	vec4 wx = w03 + vec4(-f.x - 2.0 * f.y, -f.x, f.x + 2.0 * f.y,  f.x);
	vec4 wy = w03 + vec4(-f.y - 2.0 * f.x, -f.y, f.y + 2.0 * f.x,  f.y);

	// あまり見た目が変わらないのでこちらを採用
	wx = wy = vec4(1.0, -1.0, 1.0, -1.0);
	vec2 offset_vector = vec2(dot(diff.wzxy, wx), dot(diff.wxzy, wy));
	float weight_coeff = uReducedBufferDepthCoeff / (full_depth.r + near * inv_range);

	// 最大移動量を縮小バッファ上の半テクセルに制限する
	vec2 frac_texel_offset = clamp01(frac_texel + weight_coeff * offset_vector);

	// 修正された投影テクスチャ座標
	vec2 modified_texel_coord = floor(getVarying(vHalfBufferTexelCoord)) + frac_texel_offset;
	uv = modified_texel_coord * uReducedBufferTexelSizeInv + getVarying(vHalfBufferTexelCoordOffset);
}

#endif // AL_REDUCED_BUFFER_ADJUST_UTIL_GLSL
