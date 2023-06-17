/**
 * @file	alOceanFFTPass.glsl
 * @author	Matsuda Hirokazu  (C)Nintendo
 *
 * @brief	Stockham formulation を用いた GPU FFT
 */

#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable // 明示的な場所指定には必要。無いと GPU ハング。
#endif

precision highp float;

#include "alDeclareUniformBlockBinding.glsl"
#include "alMathUtil.glsl"

#define HV_TYPE			(0) // @@ id="cHVType" choice="0,1" default="0"
#define TYPE_HORIZONTAL	(0)
#define TYPE_VERTICAL	(1)

#define IS_TEX_COORD_CENTER_ORIGIN	(0)

uniform sampler2D uInputTex;

BINDING_UBO_OTHER_FIRST uniform OceanFFTPass // @@ id="cOceanFFTPass" comment="FFT計算用パラメータ"
{
	vec4 uData; // x:transform size, y:1/transform size, z:subtransform size, w:1/subtransform size
};

#define	TRANS_SIZE		uData.x
#define	INV_TRANS_SIZE	uData.y
#define	SUB_SIZE		uData.z
#define	INV_SUB_SIZE	uData.w

//------------------------------------------------------------------------------
// 頂点シェーダ
//------------------------------------------------------------------------------
#if defined(AGL_VERTEX_SHADER)

layout (location = 0) in vec3 aPosition;	// @@ id="_p0" hint="position0"
layout (location = 1) in vec2 aTexCoord;
out vec2 vTexCrd;

void main()
{
	gl_Position.xy = 2.0 * aPosition.xy;
	gl_Position.z  = 0.0;
	gl_Position.w  = 1.0;

	vTexCrd = aTexCoord;
#if defined( AGL_TARGET_GL )
	vTexCrd.y = 1.0 - vTexCrd.y;
#endif
}

//------------------------------------------------------------------------------
// フラグメントシェーダ
//------------------------------------------------------------------------------
#elif defined(AGL_FRAGMENT_SHADER)

in	vec2	vTexCrd;
out	vec4	oColor;

#if (HV_TYPE == TYPE_HORIZONTAL)
	#define GetUV	vTexCrd.x
#else
	#define GetUV	vTexCrd.y
#endif

void main()
{
	float index = GetUV * TRANS_SIZE - 0.5;
	float twiddle_index = index;
	float even_index = floor(index * INV_SUB_SIZE) * (SUB_SIZE * 0.5) + mod(index, SUB_SIZE * 0.5);
	
	#if (HV_TYPE == TYPE_HORIZONTAL)
		vec2 even_uv = vec2(even_index + 0.5, gl_FragCoord.y) * INV_TRANS_SIZE;
		vec2 odd_uv  = vec2(even_index + TRANS_SIZE*0.5 + 0.5, gl_FragCoord.y) * INV_TRANS_SIZE;
	#elif (HV_TYPE == TYPE_VERTICAL)
		vec2 even_uv = vec2(gl_FragCoord.x, even_index + 0.5) * INV_TRANS_SIZE;
		vec2 odd_uv  = vec2(gl_FragCoord.x, even_index + TRANS_SIZE*0.5 + 0.5) * INV_TRANS_SIZE;
	#endif // HV_TYPE
	
	// 中心が原点のテクスチャから読み込む場合の対応
	#if (IS_TEX_COORD_CENTER_ORIGIN == 1)
		even_uv += vec2(0.5);
		odd_uv  += vec2(0.5);
	#endif

	// 二つの複素数の変換を同時に行う
	vec4 even = texture(uInputTex, even_uv).rgba;
	vec4 odd  = texture(uInputTex,  odd_uv).rgba;

	// バタフライダイアグラムによって表される畳み込み
	float twiddle_arg = -2.0 * PI * (twiddle_index * INV_SUB_SIZE);
	vec2  twiddle = vec2(cos(twiddle_arg), sin(twiddle_arg)); // 回転の w
	vec2  outputA = even.xy + multiplyComplex(twiddle, odd.xy);
	vec2  outputB = even.zw + multiplyComplex(twiddle, odd.zw);

	oColor = vec4(outputA, outputB);
}

#endif // defined(AGL_FRAGMENT_SHADER)

