/**
 * @file	alRenderManga.glsl
 * @author	Yuta Yamashita  (C)Nintendo
 *
 * @brief	マンガ
 */
#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable // 明示的な場所指定には必要。無いと GPU ハング。
#endif

#include "alMathUtil.glsl"
#include "alScreenUtil.glsl"
#include "alDeclareUniformBlockBinding.glsl"
#include "alGBufferUtil.glsl"

#define USING_SCREEN_AND_TEX_COORD_CALC	(1)
#include "alDefineVarying.glsl"
#include "alDeclareMdlEnvView.glsl"

uniform vec4	uParams; //x: clamp r, y: clamp g z: clamp g
uniform float	uWhiteParam;
uniform float	uBlackParam;
uniform int		uMipLevelParam;
uniform float	uScreenToneRepeatNum;
uniform float	uScreenToneRepeatNumDepth;
uniform float	uNormalParam;
uniform float	uNormalNearParam;

// 線描画用
#define KERNEL_SIZE			(0) // @@ id="cKernelSize" choice = "0,1,2" default = "0"
#define KERNEL_SIZE_0		(0)
#define KERNEL_SIZE_1		(1)
#define KERNEL_SIZE_2		(2)

#define IS_USE_FRAME		(0) // @@ id="cIsUseFrame" choice = "0,1" default = "0"

#define IS_USE_WHITE_EDGE			(1) // @@ id="cIsUseWhiteEdge" choice = "0,1" default = "1"
#define IS_USE_NORMAL_EDGE_FAR		(1) // @@ id="cIsUseNormalEdgeFar" choice = "0,1" default = "1"

uniform float uThreshold;					
uniform float uThresholdWhiteMin;			// 閾値Min(白枠)
uniform float uThresholdWhiteMax;			// 閾値Max(白枠)
uniform float uThresholdDepth;				// デプス閾値
uniform vec2  uTexel;						// 1.f/color.getWidth(), 1.f/color.getHeight()
uniform float uDepthZParam;					// 法線を太くするティスプの閾値
uniform float uWhiteEdgeDistanceNear;		// 白枠を描画する距離(近)
uniform float uWhiteEdgeDistanceFar;		// 白枠を描画する距離(遠)
uniform float uNearParam;					// Normal(ズーム近)の閾値
uniform float uWhiteAlphaBase;				// 白枠をだんだん透過する(基底値)
uniform float uWhiteAlphaAdd;				// 白枠をだんだん透過する(加算値)
uniform float uWhiteBaseColor;				// 白のベース色RGB
uniform float uBlackBaseColor;				// 黒のベース色RGB

layout( binding = 0 ) uniform sampler2D uOrgColor;
layout( binding = 1 ) uniform sampler2D uOrgDepth;
layout( binding = 2 ) uniform sampler2D uLuminance;
layout( binding = 3 ) uniform sampler2D uLuminanceMax;
layout( binding = 4 ) uniform sampler2D uLuminanceMin;
layout( binding = 5 ) uniform sampler2D uTexScreenTone;
layout( binding = 6 ) uniform sampler2D uTexScreenToneDepth;
layout( binding = 7 ) uniform sampler2D uTexNormal;


DECLARE_VARYING(float, vWhiteParam);
DECLARE_VARYING(float, vBlackParam);
DECLARE_VARYING(float, vHalfParam);
DECLARE_VARYING(float, vThresholdWhiteDisParam);

// @fixme 処理によってスコープで区切る
//------------------------------------------------------------------------------
// 頂点シェーダ
//------------------------------------------------------------------------------
#if defined( AGL_VERTEX_SHADER )

layout (location = 0) in vec3 aPosition;	// @@ id="_p0" hint="position0"

void main()
{
	gl_Position.xy = 2.0 * aPosition.xy;
	gl_Position.z  = 0.0;
	gl_Position.w  = 1.0;
	calcScreenAndTexCoord();

	// ミップマップの輝度を取得
	float ave_lumi	= textureLod( uLuminance,    vec2(0.5), uMipLevelParam ).r;
	float max_lumi	= textureLod( uLuminanceMax, vec2(0.5), uMipLevelParam ).r;
	float min_lumi	= textureLod( uLuminanceMin, vec2(0.5), uMipLevelParam ).r;

	// ３値化のパラメータ
	getVarying(vWhiteParam) = ave_lumi + (max_lumi - ave_lumi) * uWhiteParam;
	getVarying(vBlackParam) = ave_lumi - (ave_lumi - min_lumi) * uBlackParam;
	getVarying(vHalfParam)  = (vBlackParam + vWhiteParam) / 2.0;
	getVarying(vThresholdWhiteDisParam) = 1.0 / (uThresholdWhiteMax - uThresholdWhiteMin);
}

//------------------------------------------------------------------------------
// フラグメントシェーダ
//------------------------------------------------------------------------------
#elif defined( AGL_FRAGMENT_SHADER )

// 出力変数
layout( location = 0 )	out vec4 oColor;

vec3 rgb2hsv(vec3 c)
{
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));

	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c)
{
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

vec3 maxcolor4_rgb(sampler2D sampler, vec2 center, vec2 v0, vec2 v1, vec2 v2, vec2 v3)
{
	return max(	max( texture( sampler, center+v0 ).rgb, texture( sampler, center+v1 ).rgb),
				max( texture( sampler, center+v2 ).rgb, texture( sampler, center+v3 ).rgb) );
}

float maxcolor4_r(sampler2D sampler, vec2 center, vec2 v0, vec2 v1, vec2 v2, vec2 v3)
{
	return max(	max( texture( sampler, center+v0 ).r,   texture( sampler, center+v1 ).r),
				max( texture( sampler, center+v2 ).r,   texture( sampler, center+v3 ).r) );
}

vec3 mincolor4_rgb(sampler2D sampler, vec2 center, vec2 v0, vec2 v1, vec2 v2, vec2 v3)
{
	return min(	min( texture( sampler, center+v0 ).rgb, texture( sampler, center+v1 ).rgb),
				min( texture( sampler, center+v2 ).rgb, texture( sampler, center+v3 ).rgb) );
}

float mincolor4_r(sampler2D sampler, vec2 center, vec2 v0, vec2 v1, vec2 v2, vec2 v3)
{
	return min(	min( texture( sampler, center+v0 ).r,   texture( sampler, center+v1 ).r),
				min( texture( sampler, center+v2 ).r,   texture( sampler, center+v3 ).r) );
}

// 周囲4テクセルから 基点法線とのなす角が大きい(cosθが最小)の値を計算
float minNrm4_dot(sampler2D sampler, vec3 center_nml, vec2 center, vec2 v0, vec2 v1, vec2 v2, vec2 v3)
{
	GBufferInfo i0,i1,i2,i3;
	decodeWorldNrm(i0,	sampler, center+v0);	decodeWorldNrm(i1,	sampler, center+v1);
	decodeWorldNrm(i2,	sampler, center+v2);	decodeWorldNrm(i3,	sampler, center+v3);
	return min(min(dot(i0.normal, center_nml), dot(i1.normal, center_nml)),
			   min(dot(i2.normal, center_nml), dot(i3.normal, center_nml)));
}

// 黒線か評価
bool isBlackEdge(float org_depth, vec2 sc)
{
	// Color
	{
		float w = uTexel.x, h = uTexel.y;
		vec3 org_color_line	=           texture( uOrgColor, sc ).rgb;
		vec3 neighbor_rgb	=           maxcolor4_rgb( uOrgColor, sc, vec2( 0, h), vec2( w, 0), vec2( 0,-h), vec2(-w, 0));

	#if KERNEL_SIZE == KERNEL_SIZE_1
		neighbor_rgb		= max(neighbor_rgb, maxcolor4_rgb( uOrgColor, sc, vec2( w, h), vec2( w,-h), vec2(-w,-h), vec2(-w, h)));
	#elif KERNEL_SIZE == KERNEL_SIZE_2
		neighbor_rgb		= max(neighbor_rgb, maxcolor4_rgb( uOrgColor, sc, vec2( w, h), vec2( w,-h), vec2(-w,-h), vec2(-w, h)));
		w *= 2.0; h *= 2.0;
		neighbor_rgb		= max(neighbor_rgb, maxcolor4_rgb( uOrgColor, sc, vec2( 0, h), vec2( w, 0), vec2( 0,-h), vec2(-w, 0)));
	#endif	// KERNEL_SIZE_2

		vec3 diff_rgb	=  abs(neighbor_rgb - org_color_line);
		float diff		=  max(diff_rgb.r, max(diff_rgb.g, diff_rgb.b));
		if(uThreshold <= diff)
			return true;
	}

	// Depth
	{
		float w = uTexel.x, h	= uTexel.y;
		float neighbor_d		= 					maxcolor4_r( uOrgDepth, sc, vec2( 0, h), vec2( w, 0), vec2( 0,-h), vec2(-w, 0));
		neighbor_d				= max(neighbor_d,	maxcolor4_r( uOrgDepth, sc, vec2( w, h), vec2( w,-h), vec2(-w,-h), vec2(-w, h)));
		w *= 2.0; h *= 2.0;
		neighbor_d				= max(neighbor_d,	maxcolor4_r( uOrgDepth, sc, vec2( 0, h), vec2( w, 0), vec2( 0,-h), vec2(-w, 0)));

		float diff_depth;
		diff_depth		= abs(neighbor_d	  - org_depth);
		if(uThresholdDepth <= diff_depth)
			return true;
	}

	// Normal
	{
		float w = uTexel.x, h = uTexel.y;
		vec3 center_nml;
		{
			GBufferInfo g_buf_center;
			decodeWorldNrm(g_buf_center, uTexNormal, sc);
			center_nml = g_buf_center.normal;
		}

		{
			float def = minNrm4_dot(uTexNormal, center_nml, sc, vec2( 0, h), vec2( w, 0), vec2( 0,-h), vec2(-w, 0));
			if(def < uNormalParam){
				return true;
			}
		}

		// ズームで輪郭を太くする。
		if((1.0 - org_depth) > uDepthZParam){
			float def = minNrm4_dot(uTexNormal, center_nml, sc, vec2( w, h), vec2( w,-h), vec2(-w,-h), vec2(-w, h));
			if(def < uNormalNearParam){
				return true;
			}
		}
	}
	return false;
}

// 白線か？
// @param thickness 白線の太さ
// @return 白線ならその時の強度。ちがうならば 0.0 を返す。
float whiteEdgeIntensity(float org_depth, float neighbor_depth, int thickness)
{
	// 周辺の最小深度が遠すぎる
	if(uWhiteEdgeDistanceFar < neighbor_depth )	return 0.0;

	// 距離時応じて細くする
	if( uWhiteEdgeDistanceNear < neighbor_depth &&
		(0.2 * (5-thickness) < (neighbor_depth - uWhiteEdgeDistanceNear) / (uWhiteEdgeDistanceFar - uWhiteEdgeDistanceNear) ) )	return 0.0;

	float diff_depth_min  = org_depth - neighbor_depth;

	// 周辺の最小深度と基点の深度との差が小さすぎる
	if(diff_depth_min < uThresholdWhiteMin )		return 0.0;

	// 周辺の最小深度と基点の深度との差によって、白線の濃さをグラデーションさせる
	float white_edge_intensity = 1.0;
	if(diff_depth_min <= uThresholdWhiteMax){
		white_edge_intensity = (diff_depth_min - uThresholdWhiteMin) * vThresholdWhiteDisParam;
	}
	return white_edge_intensity;
}

void main()
{
	// オリジナルカラー→グレースケール
	vec3 org_color	= texture	( uOrgColor,  getScreenCoord() ).rgb;
	float c         = ( 0.298912f * org_color.r + 0.586611f * org_color.g + 0.114478f * org_color.b );

	// ４値化
	vec4 buf_color = vec4(uBlackBaseColor, uBlackBaseColor, uBlackBaseColor, 1.0);
	if(c <= vBlackParam){
	}
	else if(c > vWhiteParam){
		buf_color = vec4(uWhiteBaseColor, uWhiteBaseColor, uWhiteBaseColor, 1.0);
	}
	else{
		ivec2 tex_size = textureSize(uTexNormal, 0);
		float screen_coord_x = getScreenCoord().x * float(tex_size.x) / float(tex_size.y);
		float screen_coord_y = getScreenCoord().y;
		if(c > vHalfParam){
			buf_color.rgb = texture(uTexScreenTone, 	 vec2(screen_coord_x, screen_coord_y) * uScreenToneRepeatNum).rgb;
		}else{
			buf_color.rgb = texture(uTexScreenToneDepth, vec2(screen_coord_x, screen_coord_y) * uScreenToneRepeatNumDepth).rgb;
		}
	}

	vec2 sc = getScreenCoord();
	float org_depth	=				texture( uOrgDepth, sc ).r;

	// 黒線
	if(isBlackEdge(org_depth, sc)){
		buf_color.rgb = vec3(0);
	}

	// 白線
#if IS_USE_WHITE_EDGE
	{
		float w = uTexel.x,	h = uTexel.y;
		float neighbor_d_min1 =			mincolor4_r( uOrgDepth, sc, vec2( 0, h), vec2( w, 0), vec2( 0,-h), vec2(-w, 0));
		float diff_depth_min, diff_depth_min2, diff_depth_min3, diff_depth_min4, diff_depth_min5;
		w *= 2.0; h *= 2.0;
		float neighbor_d_min2 = min(neighbor_d_min1, mincolor4_r( uOrgDepth, sc, vec2( w, h), vec2( w,-h), vec2(-w,-h), vec2(-w, h)));
		float neighbor_d_min3 = min(neighbor_d_min2, mincolor4_r( uOrgDepth, sc, vec2( 0, h), vec2( w, 0), vec2( 0,-h), vec2(-w, 0)));
		w *= 1.8; h *= 1.8;
		float neighbor_d_min4 = min(neighbor_d_min3, mincolor4_r( uOrgDepth, sc, vec2( 0, h), vec2( w, 0), vec2( 0,-h), vec2(-w, 0)));
		neighbor_d_min4		  = min(neighbor_d_min4, mincolor4_r( uOrgDepth, sc, vec2( w, h), vec2( w,-h), vec2(-w,-h), vec2(-w, h)));
		w *= 1.5; h *= 1.5;
		float neighbor_d_min5 = min(neighbor_d_min4, mincolor4_r( uOrgDepth, sc, vec2( 0, h), vec2( w, 0), vec2( 0,-h), vec2(-w, 0)));
		neighbor_d_min5 	  = min(neighbor_d_min5, mincolor4_r( uOrgDepth, sc, vec2( w, h), vec2( w,-h), vec2(-w,-h), vec2(-w, h)));


#define whiteEdge(neighbor_depth, distance)	\
		{	float intensity = whiteEdgeIntensity(org_depth, neighbor_depth, distance);	\
			if( intensity != 0.0 ){	\
				buf_color.rgb += vec3(uWhiteAlphaBase+uWhiteAlphaAdd*(6-distance)) * intensity;		\
				oColor = buf_color;	\
				return;	\
		} }

		whiteEdge(neighbor_d_min1, 1);
		whiteEdge(neighbor_d_min2, 2);
		whiteEdge(neighbor_d_min3, 3);
		whiteEdge(neighbor_d_min4, 4);
		whiteEdge(neighbor_d_min5, 5);
	}
#endif //IS_USE_WHITE_EDGE


	oColor = buf_color;
}
#endif // defined( AGL_FRAGMENT_SHADER )
