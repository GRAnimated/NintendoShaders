/**
 * @file	alOceanUpdateHtDxDz.glsl
 * @author	Matsuda Hirokazu  (C)Nintendo
 *
 * @brief	H(0) -> H(t), D(x, t), D(z, t)
 *			FFTの前に初期スペクトルデータを現在のスペクトルに更新する
 */

#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable // 明示的な場所指定には必要。無いと GPU ハング。
#endif

precision highp float;

#include "alDeclareUniformBlockBinding.glsl"
#include "alMathUtil.glsl"

#define IS_TEX_COORD_CENTER_ORIGIN	(0)

uniform sampler2D uInitSpectrum;

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

const float G	= 9.81;
const float KM	= 370.0;

BINDING_UBO_OTHER_FIRST uniform OceanUpdateSpectrum // @@ id="cOceanInitSpectrum" comment="海初期スペクトルパラメータ"
{
	vec4	uData; // x : Resolution, y : 1/海のサイズ, z : Choppiness, w : Height Scale
	vec4	uData2;// x : Time
};

#define RESOLUTION			uData.x
#define INV_SIZE			uData.y
#define CHOPPINESS			uData.z
#define HEIGHT_SCALE		uData.w
#define TIME				uData2.x

float square (in float x) { return x*x; }
float omega	 (in float k) { return sqrt(G * k * (1.0 + square(k/KM))); }

in	vec2	vTexCrd;
out	vec4	oColor;

void main()
{
	vec2 coord = gl_FragCoord.xy - 0.5;
	
	#if (IS_TEX_COORD_CENTER_ORIGIN == 0)
		float n = (coord.x < RESOLUTION*0.5) ? coord.x : coord.x - RESOLUTION;
		float m = (coord.y < RESOLUTION*0.5) ? coord.y : coord.y - RESOLUTION;
	#else
		float n = coord.x - RESOLUTION*0.5;
		float m = coord.y - RESOLUTION*0.5;
	#endif

	vec2 wave_vec = (2.0 * PI * vec2(n, m)) * INV_SIZE;
	float k = length(wave_vec) + 0.00001; // 波数ベクトルの長さ(k = 2π/λ (λ=波長))
	float w = omega(k) * TIME;
	vec2 phase_vec = vec2(cos(w), sin(w));
	vec2 h0  = texture(uInitSpectrum, vTexCrd).rg;
	vec2 h0x = texture(uInitSpectrum, vec2(1.0 - vTexCrd + 1.0/RESOLUTION)).rg;
	h0x.y *= -1.0;

	vec2 h = multiplyComplex(h0,  phase_vec)
		   + multiplyComplex(h0x, vec2(phase_vec.x, -phase_vec.y));
	vec2 hx = -multiplyByI(h * (wave_vec.x / k)) * CHOPPINESS;
	vec2 hz = -multiplyByI(h * (wave_vec.y / k)) * CHOPPINESS;

	oColor = vec4(hx + multiplyByI(h*HEIGHT_SCALE), hz);
}

#endif // defined(AGL_FRAGMENT_SHADER)
