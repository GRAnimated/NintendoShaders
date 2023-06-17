/**
 * @file	alDeclareAttribute.glsl
 * @author	Yosuke Mori  (C)Nintendo
 *
 * @brief	頂点アトリビュートの定義
 */
#if defined(AGL_VERTEX_SHADER)

#define	LOC_ATTR_POSITION			layout(location = 0)
#define	LOC_ATTR_NORMAL				layout(location = 1)
#define	LOC_ATTR_COLOR				layout(location = 2)
#define	LOC_ATTR_TANGENT0			layout(location = 3)
#define	LOC_ATTR_TEX_COORD0			layout(location = 4)
#define	LOC_ATTR_TEX_COORD1			layout(location = 5)
#define	LOC_ATTR_TEX_COORD2			layout(location = 6)
#define	LOC_ATTR_TEX_COORD3			layout(location = 7)
#define	LOC_ATTR_TANGENT1			layout(location = 8)
#define	LOC_ATTR_BLEND_WEIGHT		layout(location = 10)
#define	LOC_ATTR_BLEND_INDEX		layout(location = 11)

#if defined(AGL_TARGET_GX2) || defined(AGL_VERTEX_SHADER)
#define FLAT				/* none */
#else
#define FLAT				flat
#endif

LOC_ATTR_POSITION			in vec3		aPosition;		// @@ id="_p0"	hint="position0"	label="頂点座標" group="attribute"
LOC_ATTR_NORMAL				in vec3		aNormal;		// @@ id="_n0"	hint="normal0"		label="頂点法線" group="attribute"
LOC_ATTR_COLOR				in vec4		aColor;			// @@ id="_c0"	hint="color0"		label="頂点カラー" group="attribute"
LOC_ATTR_TANGENT0			in vec4		aTangent0;		// @@ id="_t0"	hint="tangent0"		label="タンジェント0" group="attribute"
LOC_ATTR_TANGENT1			in vec4		aTangent1;		// @@ id="_t1"	hint="tangent1"		label="タンジェント1" group="attribute"
LOC_ATTR_TEX_COORD0			in vec2		aTexCoord0;		// @@ id="_u0"	hint="uv0"			label="テクスチャ座標0" group="attribute"
LOC_ATTR_TEX_COORD1			in vec2		aTexCoord1;		// @@ id="_u1"	hint="uv1"			label="テクスチャ座標1" group="attribute"
LOC_ATTR_TEX_COORD2			in vec2		aTexCoord2;		// @@ id="_u2"	hint="uv2"			label="テクスチャ座標2" group="attribute"
LOC_ATTR_TEX_COORD3			in vec2		aTexCoord3;		// @@ id="_u3"	hint="uv3"			label="テクスチャ座標3" group="attribute"
LOC_ATTR_BLEND_WEIGHT		in vec4		aBlendWeight;	// @@ id="_w0"	hint="blendweight0"	label="スキニング重み" group="attribute"
LOC_ATTR_BLEND_INDEX		FLAT in ivec4	aBlendIndex;	// @@ id="_i0"	hint="blendindex0"	label="スキニングインデックス" group="attribute"

// @@ interleave="_p0"
// @@ interleave="_n0"
// @@ interleave="_c0"
// @@ interleave="_t0"
// @@ interleave="_t1"
// @@ interleave="_u0 _u1"
// @@ interleave="_u2 _u3"
// @@ interleave="_w0"
// @@ interleave="_i0"

#endif // defined(AGL_VERTEX_SHADER)
