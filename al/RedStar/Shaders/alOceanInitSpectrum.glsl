/**
 * @file	alOceanInitSpectrum.glsl
 * @author	Matsuda Hirokazu  (C)Nintendo
 *
 * @brief	風の方向を与えて初期スペクトラムをレンダリング
 */

#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable // 明示的な場所指定には必要。無いと GPU ハング。
#endif

precision highp float;

#define SPECTRUM_TYPE	(0) // @@ id="cSpectrumType" choice="0,1" default="0"
#define TYPE_PHILLIPS_SPECTRUM	(0)
#define TYPE_ORIGINAL			(1)

#define	USING_GAUSS_RANDOM	(1) // @@ id="cUsingGaussRandom" choice="0,1" default="1"

#define IS_TEX_COORD_CENTER_ORIGIN	(0)

#include "alDeclareUniformBlockBinding.glsl"
#include "alMathUtil.glsl"
#include "alGpuRandom.glsl"

uniform sampler1D uRandomTex1D;

//------------------------------------------------------------------------------
// 頂点シェーダ
//------------------------------------------------------------------------------
#if defined(AGL_VERTEX_SHADER)

layout (location = 0) in vec3 aPosition;	// @@ id="_p0" hint="position0"

void main()
{
	gl_Position.xy = 2.0 * aPosition.xy;
	gl_Position.z  = 0.0;
	gl_Position.w  = 1.0;
}

//------------------------------------------------------------------------------
// フラグメントシェーダ
//------------------------------------------------------------------------------
#elif defined(AGL_FRAGMENT_SHADER)

const float G	= 9.81;
const float KM	= 370.0;
const float CM	= 0.23;

BINDING_UBO_OTHER_FIRST uniform OceanInitSpectrum // @@ id="cOceanInitSpectrum" comment="海初期スペクトルパラメータ"
{
	vec4	uWind; // xy : wind dir,  z : length,  w : dir depend
	vec4	uData; // x : Resolution,  y : 1/海のサイズ,  z : Amplitude,  w : 大きな波数の波を抑えるためのパラメータ
	vec4	uData2;// xy : ランダムピクセルオフセット
};

#define WIND_DIR			uWind.xy
#define WIND_LEN			uWind.z
#define WIND_DEPEND			uWind.w
#define RESOLUTION			uData.x
#define INV_SIZE			uData.y
#define AMPLITUDE			uData.z
#define SMALL_L_COEF		uData.w
#define RND_PIXEL_OFFSET	uData2.xy


float square (in float x) { return x*x; }
float omega	 (in float k) { return sqrt(G * k * (1.0 + square(k/KM))); }
float tanh	 (in float x) { return (1.0 - exp(-2.0 * x)) / (1.0 + exp(-2.0 * x)); }

out vec4	oColor;

/**
 *	スペクトルを格納
 */
void storeSpectrum(out vec4 color, in float P)
{
	#if (USING_GAUSS_RANDOM == 1)
	{
		vec4 seed = texture(uRandomTex1D, gl_FragCoord.y * RND_PIXEL_OFFSET.y
										+ gl_FragCoord.x * RND_PIXEL_OFFSET.x);
		float r1 = GpuRandomGauss(seed);
		float r2 = GpuRandomGauss(seed);
		color = vec4(P*r1, P*r2, 0.0, 0.0);
	}
	#else
	{
		if(isnan(P)){
			color = vec4(0,1,0,0);
		}else{
			color = vec4(P,P, 0.0, 0.0);
		}
	}
	#endif // USING_GAUSS_RANDOM
}

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
	vec2 wave_vec = (2.0 * PI * vec2(n+0.0001, m+0.0001)) * INV_SIZE;

	float k = length(wave_vec); // 波数ベクトルの長さ(k = 2π/λ (λ=波長))
	float k2 = k*k;
	float dk = 2.0 * PI * INV_SIZE;

	#if (SPECTRUM_TYPE == TYPE_PHILLIPS_SPECTRUM)
	{
		float L = WIND_LEN * WIND_LEN / G;
		float l = L * SMALL_L_COEF;
		float exp_arg = -1.0/(k2*L*L) - k*l;
		float cosPhi = dot(WIND_DIR, normalize(wave_vec));
		float P = AMPLITUDE
					* pow(k, -4.0)
					* exp(exp_arg);
		// 逆向きを減らす
		P *= mix(1.0, WIND_DEPEND, step(0.0, -cosPhi)) // 逆向きを減らす
			 * square(cosPhi) // 垂直な成分を減らす
			 ;
		P = sqrt(P*0.5)*dk;
		storeSpectrum(oColor, P);
	}
	#elif (SPECTRUM_TYPE == TYPE_ORIGINAL)
	{
	}
	#endif // SPECTRUM_TYPE
}

#endif // defined(AGL_FRAGMENT_SHADER)
