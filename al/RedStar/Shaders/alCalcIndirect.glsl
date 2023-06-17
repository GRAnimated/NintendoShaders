/**
 * @file	alCalcIndirect.glsl
 * @author	Yosuke Mori  (C)Nintendo
 *
 * @brief	インダイレクトまわり計算
 */
//------------------------------------------------------------------------------
// 頂点シェーダ
//------------------------------------------------------------------------------
#if defined(AGL_VERTEX_SHADER)

//------------------------------------------------------------------------------
// フラグメントシェーダ
//------------------------------------------------------------------------------
#elif defined(AGL_FRAGMENT_SHADER)

#define toScreenUv(uv)	\
{						\
	uv = 0.5 * uv + 0.5;\
	uv.y = 1.0 - uv.y;	\
}

vec3 calcScreenIndirect(sampler2D tex, in vec2 uv)
{
	// スクリーン座標に直す
	toScreenUv(uv);
	return texture( tex, uv ).rgb;
}

vec3 calcIndirectWithDepth(sampler2D tex
						 , sampler2D depth
						 , in float linear_depth
						 , in vec2 base_uv
						 , in vec2 ind_uv)
{
	vec2 offset = normalize(ind_uv);
	// テクスチャ座標系に変換
	offset.x *= InvScrSizeX;
	offset.y *= InvScrSizeY;

	// 4.0が「伸ばす大きさ」
	vec2 depth_fetch_uv = base_uv + ind_uv + offset * 4.0;
	// スクリーン座標に直す
	toScreenUv(depth_fetch_uv);
	
	float depth_tex  = texture(depth, depth_fetch_uv).r;

	// 現在のデプスと比較（0 or 1）depth_tex - linear_depth を使えば深さが表現可能
	float depth_diff = 0.5 * sign(depth_tex - linear_depth) + 0.5;

	// 元のオフセットに反映
	vec2 uv = base_uv + ind_uv * depth_diff;

	// スクリーン座標に直す
	toScreenUv(uv);

	return texture( tex, uv ).rgb;
}

#define calcDistortion(tex_du, tex_dv, uv)				\
{														\
	tex_du = dFdx(uv);									\
	tex_dv = dFdy(uv);									\
	if (DISTORTION_TYPE == DISTORTION_UV_NORMALIZE)		\
	{													\
		tex_du = normalize(tex_du);						\
		tex_dv = normalize(tex_dv);						\
	}													\
}

#define  calcTextureIndirectSub( fuv, sampler, vtx, no )								\
{																						\
    if (ENABLE_INDIRECT##no == 1 )														\
    {																					\
	    vec4 indirect_map;																\
	    selectSampler(indirect_map, sampler, vtx, INDIRECT##no##_SRC_MAP); 				\
		fuv.texCoordIndirect##no.x += (indirect_map.r - 0.5) * uIndirect##no##Scale.x;	\
		fuv.texCoordIndirect##no.y += (indirect_map.g - 0.5) * uIndirect##no##Scale.y;	\
    }																					\
}

// インダイレクト
#define calcTextureIndirect( fuv, sampler, vtx )		\
{														\
	if (INDIRECT0_SRC_MAP != COLOR_CHOICE_BLEND0 && INDIRECT0_SRC_MAP != COLOR_CHOICE_BLEND1 && INDIRECT0_SRC_MAP != COLOR_CHOICE_BLEND2 \
		&& INDIRECT0_SRC_MAP != COLOR_CHOICE_BLEND3 && INDIRECT0_SRC_MAP != COLOR_CHOICE_BLEND4 && INDIRECT0_SRC_MAP != COLOR_CHOICE_BLEND5) \
	{													\
		calcTextureIndirectSub( fuv, sampler, vtx, 0 );	\
		calcTextureIndirectSub( fuv, sampler, vtx, 1 );	\
	}													\
}

// インダイレクト(ブレンドの結果を使う場合)
#define calcTextureIndirectAfter( fuv, sampler, vtx )	\
{														\
	if (INDIRECT0_SRC_MAP == COLOR_CHOICE_BLEND0 || INDIRECT0_SRC_MAP == COLOR_CHOICE_BLEND1 || INDIRECT0_SRC_MAP == COLOR_CHOICE_BLEND2 \
		|| INDIRECT0_SRC_MAP == COLOR_CHOICE_BLEND3 || INDIRECT0_SRC_MAP == COLOR_CHOICE_BLEND4 || INDIRECT0_SRC_MAP == COLOR_CHOICE_BLEND5) \
	{													\
		calcTextureIndirectSub( fuv, sampler, vtx, 0 );	\
		calcTextureIndirectSub( fuv, sampler, vtx, 1 );	\
	}													\
}

// インダイレクトの距離補正
#define calcIndirectDistCorrect( uv, view_diff, frame_buf_depth, vtx )		\
{																			\
	float diff_depth = -abs(frame_buf_depth - vtx.depth);					\
	diff_depth = clamp01(1.0 - exp2(diff_depth * uIndirectDepthScale));		\
	view_diff *= diff_depth;												\
	uv = vtx.pos_proj + view_diff.xy;										\
	toScreenUv(uv);															\
}

#endif
