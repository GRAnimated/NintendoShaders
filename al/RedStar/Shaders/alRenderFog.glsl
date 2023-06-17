/**
 * @file	alRenderFog.glsl
 * @author	Yosuke Mori  (C)Nintendo
 *
 * @brief	フォグ
 */

#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable // 明示的な場所指定には必要。無いと GPU ハング。
#endif

//for fetchCubeMap
#define IS_USE_TEXTURE_BIAS 0

// バリエーション
#define IS_ENABLE_Y_FOG						(0) // @@ id="cIsEnableYFog"					choice="0,1,2"		default="0"
#define IS_ENABLE_Z_FOG						(0) // @@ id="cIsEnableZFog"					choice="0,1,2"		default="0"
#define IS_APPLY_SKY						(0) // @@ id="cIsApplySky"						choice="bool"		default="0"
#define IS_LINEAR_DEPTH						(0) // @@ id="cIsLinearDepth"					choice="bool"		default="0"
#define IS_IN_WATER							(0) // @@ id="cIsInWater"						choice="bool"		default="0"
#define FOG_BLEND_TYPE						(0) // @@ id="cFogBlendType"					choice="0,1,2,3,4"	default="0"
#define Y_FOG_DISTANCE_SLOPE				(0) // @@ id="cYFogDistanceSlope"				choice="0,1,2"		default="0"
#define OUTPUT_BLEND_TYPE					(0) // @@ id="cFogOutputBlendType"				choice="0,1"		default="0"

#define FOG_BLEND_TYPE_MIX					(0)
#define FOG_BLEND_TYPE_ZFOG					(1)
#define FOG_BLEND_TYPE_YFOG					(2)
#define FOG_BLEND_TYPE_MIX_LOW				(3)
#define FOG_BLEND_TYPE_MULT					(4)

#define Y_FOG_DISTANCE_NONE					(0)
#define Y_FOG_DISTANCE_DEC					(1)
#define Y_FOG_DISTANCE_INC					(2)

#define OUTPUT_BLEND_ADD					(0)
#define OUTPUT_BLEND_MULT					(1)

#include "alDeclareUniformBlockBinding.glsl"
#include "alDeclareMdlEnvView.glsl"
#include "alMathUtil.glsl"
#include "alDefineVarying.glsl"
#include "alDefineSampler.glsl"
#include "alHdrUtil.glsl"
#include "alFetchCubeMap.glsl"

BINDING_SAMPLER_DEPTH					uniform sampler2D cDepth;
BINDING_SAMPLER_ENV_CUBE_MAP_ROUGHNESS	uniform samplerCube cTexCubeMapSky;
BINDING_SAMPLER_PROC_TEXTURE_3D			uniform sampler3D cNoise3D;
BINDING_SAMPLER_CAUSTICS_3D				uniform sampler3D cCaustics3D;

BINDING_UBO_OTHER_FIRST	uniform Fog
{
	// フォグ
	vec4	cFogColor;		// .a にはフォグのslope(フォグのかかり具合)
	float	cFogStart;
	float	cFogMax;
	// Y フォグ
	vec4	cYFogColor;		// .a にはフォグのslope(フォグのかかり具合)
	float	cYFogStart;
	float	cYFogMax;
	vec3	cViewAxisY;		// Y 軸方向
	vec3	cViewAxisZ;		// Z 軸方向
	float	cYFogUpStart;	
	float	cYFogUpRate;
	float	cYFogDistScale;

	// LOD
	float	cSkyMip;		// SKYLOD

	// for noise
	vec4 	cNoiseParam; // xyz : tex crd add,  w : tex crd scale
	vec4 	cNoiseParamYFog; // xyz : tex crd add,  w : tex crd scale
	vec4	cNoiseScale; // x : z fog,  y : y fog,  z : z fog dist coef,  w : y fog dist coef

	// コースティクス
	vec4	cCausticsParam;		// x : start,  y : power,  z : caustics tex crd scale,  w : add_y for animation
	vec4 	cCausticsParam2;	// x : intensity,  y : tex crd scale y
};

#define NOISE_TEX_CRD_ADD	cNoiseParam.xyz
#define NOISE_TEX_CRD_SCALE	cNoiseParam.w

#define NOISE_TEX_CRD_ADD_YFOG		cNoiseParamYFog.xyz
#define NOISE_TEX_CRD_SCALE_YFOG	cNoiseParamYFog.w

#define NOISE_INTENSITY			cNoiseScale.x
#define NOISE_INTENSITY_YFOG	cNoiseScale.y
#define NOISE_DIST_COEF			cNoiseScale.z
#define NOISE_DIST_COEF_YFOG	cNoiseScale.w

#define CAUSTICS_START				cCausticsParam.x
#define CAUSTICS_POWER				cCausticsParam.y
#define CAUSTICS_TEX_CRD_ADD_Y		vec3(0.0, cCausticsParam.w, 0.0)
#define CAUSTICS_INTENSITY			cCausticsParam2.x
#define CAUSTICS_TEX_CRD_SCALE_Y	cCausticsParam2.y
#define CAUSTICS_TEX_CRD_SCALE		vec3(cCausticsParam.z, cCausticsParam.z*CAUSTICS_TEX_CRD_SCALE_Y, cCausticsParam.z)

#if (IS_LINEAR_DEPTH == 0)
DECLARE_VARYING(vec3,	vParameters);
#endif

/**
 *	頂点シェーダ
 */
#if defined(AGL_VERTEX_SHADER)

layout ( location = 0 ) in vec3 aPosition;
layout ( location = 1 )	in vec2	aTexCoord1;
out	vec2	vTexCoord;
out	vec2	vScreen;

void main()
{
	gl_Position.xy = aPosition.xy * 2;
	gl_Position.z = 1.0;
	gl_Position.w = 1.0;
	vTexCoord = aTexCoord1;
	vScreen.xy = gl_Position.xy / gl_Position.w;
#if defined( AGL_TARGET_GX2 ) || defined( AGL_TARGET_NVN )
	vScreen.y *= -1.0;
#endif
	vScreen.xy *= -cTanFovyHalf.xy;
	vScreen.xy -= cScrProjOffset.xy;

#if (IS_LINEAR_DEPTH == 0)
	getVarying(vParameters)	= vec3( -cFar * cInvRange, cRange / cNear, cNear * cInvRange );
#endif
}

#elif defined(AGL_FRAGMENT_SHADER)

in	vec2	vTexCoord;
in	vec2	vScreen;
layout(location = 0)	out vec4 oColor;

void main()
{

	float depth = 1.0;
	#if (IS_LINEAR_DEPTH == 1)
	{
		depth = texture(cDepth, vTexCoord).r;
	}
	#else
	{	
		depth = texture(cDepth, vTexCoord).r;
		float a = getVarying(vParameters).x;
		float b = getVarying(vParameters).y;
		depth = a / ((depth + a) * b);
		depth = depth - getVarying(vParameters).z;
	}
	#endif

	vec3 view_pos;
	view_pos.z = -( depth * cRange + cNear );
	view_pos.xy = vScreen * view_pos.z;

	// フォグ [1 - e ^ -a(x + b)]
	float fog_intensity = 0.0;
	vec3 pos_w = multMtx34Vec3(cInvView, view_pos);
	#if (IS_ENABLE_Z_FOG != 0)
		float fog_dist_intensity = cFogColor.a * (-view_pos.z + cFogStart);
		fog_intensity = clamp01(clamp01(1.0 - exp2(-fog_dist_intensity)) * cFogMax);
		#if (FOG_BLEND_TYPE == FOG_BLEND_TYPE_MULT)
		{
			if(fog_intensity < 0.00001) discard;
		}
		#endif
	#endif

	// Yフォグ [1 - e ^ -a(x + b)]
	float y_fog_intensity = 0.0;
	float dot_y = dot(view_pos, cViewAxisY);
	#if (IS_ENABLE_Y_FOG != 0)	
		float fog_start = cYFogStart-1;
		float fog_pow   = cYFogColor.a;
		// FIXME: 水際対策。遠くにいくほどyのスタートを上にあげる
		#if IS_IN_WATER
			fog_start += clamp((-dot(view_pos, cViewAxisZ) - cYFogUpStart)* cYFogUpRate, 0, 400); //FIXME 決めうちclamp値
		#endif

		float y_fog_dist_intensity = fog_pow * (-dot_y + fog_start);
		y_fog_intensity = clamp01(clamp01(1.0 - exp2(-y_fog_dist_intensity)) * cYFogMax);

		#if (Y_FOG_DISTANCE_SLOPE == Y_FOG_DISTANCE_DEC)
		{
			y_fog_intensity *= clamp01(exp2(view_pos.z * cYFogDistScale));
		}
		#elif (Y_FOG_DISTANCE_SLOPE == Y_FOG_DISTANCE_INC)
		{
			y_fog_intensity *= clamp01(1.0 - exp2(view_pos.z * cYFogDistScale));
		}
		#endif

		#if (FOG_BLEND_TYPE == FOG_BLEND_TYPE_MULT)
		{
			if(y_fog_intensity < 0.00001) discard;
		}
		#endif
	#endif

	if(fog_intensity + y_fog_intensity < 0.00001) discard;

	// ノイズテクスチャ適用
	#if (IS_ENABLE_Z_FOG == 2)
	{
		float nz_fog = texture(cNoise3D, pos_w*NOISE_TEX_CRD_SCALE + NOISE_TEX_CRD_ADD).r - 0.5;
		nz_fog *= clamp01(exp2(-fog_dist_intensity*NOISE_DIST_COEF));
		fog_intensity = clamp01(fog_intensity + fog_intensity*nz_fog*NOISE_INTENSITY);
	}
	#endif

	// ノイズテクスチャ適用
	#if (IS_ENABLE_Y_FOG == 2)
	{
		float nz_yfog = texture(cNoise3D, pos_w*NOISE_TEX_CRD_SCALE_YFOG + NOISE_TEX_CRD_ADD_YFOG).r - 0.5;
		nz_yfog *= clamp01(exp2(-y_fog_dist_intensity*NOISE_DIST_COEF_YFOG));
		y_fog_intensity = clamp01(y_fog_intensity + y_fog_intensity*nz_yfog*NOISE_INTENSITY_YFOG);
	}
	#endif

	float transmittance = 1.0;
	vec3 final_fog_color = vec3(1.0);

	#if (FOG_BLEND_TYPE == FOG_BLEND_TYPE_MIX)
	{
		float sum_fog_intensity = fog_intensity + y_fog_intensity + 0.00001; //0割を防ぐ
		float mix_rate = fog_intensity / sum_fog_intensity;
		final_fog_color = mix(cYFogColor.rgb, cFogColor.rgb, mix_rate);
		transmittance = clamp01((1.0 - fog_intensity) * (1.0 - y_fog_intensity));
	}
	#elif (FOG_BLEND_TYPE == FOG_BLEND_TYPE_ZFOG)
	{
		final_fog_color = (y_fog_intensity == 0.0) ? cFogColor.rgb : mix(cYFogColor.rgb , cFogColor.rgb, fog_intensity);
		transmittance = clamp01((1.0 - fog_intensity) * (1.0 - y_fog_intensity));
	}
	#elif (FOG_BLEND_TYPE == FOG_BLEND_TYPE_YFOG)
	{
		final_fog_color = (fog_intensity == 0.0) ? cYFogColor.rgb : mix(cFogColor.rgb , cYFogColor.rgb, y_fog_intensity);
		transmittance = clamp01((1.0 - fog_intensity) * (1.0 - y_fog_intensity));
	}
	#elif (FOG_BLEND_TYPE == FOG_BLEND_TYPE_MIX_LOW)
	{
		final_fog_color = (cYFogColor.rgb + cFogColor.rgb) * 0.5;
		transmittance = clamp01((1.0 - fog_intensity) * (1.0 - y_fog_intensity));
	}
	#elif (FOG_BLEND_TYPE == FOG_BLEND_TYPE_MULT)
	{
		float sum_fog_intensity = fog_intensity + y_fog_intensity + 0.0001; //0割を防ぐ
		float mix_rate = fog_intensity / sum_fog_intensity;
		final_fog_color = mix(cYFogColor.rgb, cFogColor.rgb, mix_rate);
		transmittance = clamp01(1.0 - fog_intensity * y_fog_intensity);
	}
	#endif

	// フォグを空の色になじませる
	#if IS_APPLY_SKY
	{
		vec4 sky_color = vec4(0.0);
		vec3 eye_to_pos = normalize(view_pos);
		vec3 fetch_dir = rotMtx33Vec3(cInvView, eye_to_pos);
		fetchCubeMapConvertHdr(sky_color, cTexCubeMapSky, fetch_dir, cSkyMip);
		#if IS_IN_WATER
			float rate = clamp01(transmittance * 15.0 + 0.5);//FIXME 適当な定数
			sky_color.rgb = mix(sky_color.rgb, vec3(1.0), rate);// sky_color, transmittance);
		#endif
		final_fog_color =  final_fog_color * sky_color.rgb;
	}
	#endif

	// コースティクス
	vec3 add_color = vec3(0.0);
	#if (IS_ENABLE_Y_FOG != 0 && IS_IN_WATER)
	{
		// Caustics
		float caustics_dist_intensity = -CAUSTICS_POWER * (-dot_y + CAUSTICS_START);
		caustics_dist_intensity = clamp01(clamp01(1.0 - exp2(caustics_dist_intensity)));
		add_color = texture(cCaustics3D, pos_w*CAUSTICS_TEX_CRD_SCALE + CAUSTICS_TEX_CRD_ADD_Y).rgb * (transmittance * CAUSTICS_INTENSITY * caustics_dist_intensity);
	}
	#endif

	#if OUTPUT_BLEND_TYPE == OUTPUT_BLEND_ADD
	{
		// 1でフォグがかかる、0だとフォグがかからない(=1.0 - transmittance:透過度の逆)
		oColor = vec4(final_fog_color * (1.0 - transmittance) + add_color, transmittance);
	}
	#else
	{
		vec4 low_color = vec4(1.0, 1.0, 1.0, 0.0);
		vec3 color = mix(final_fog_color.rgb, low_color.rgb, transmittance);

		oColor = vec4(color.rgb, 1.0);
		oColor.rgb += add_color;
	}
	#endif
}

#endif

