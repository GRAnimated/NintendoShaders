/**
 * @file	alEdgeEffect.glsl
 * @author	Tanaka Wataru  (C)Nintendo
 *
 * @brief	エッジエフェクト
 */

#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable
#endif

#define IS_NEED_NORMAL				(0) // include に必要
#define IS_ENABLE_NORMALMAP			(0)

#include "alDeclareUniformBlockBinding.glsl"
#include "alDefineSampler.glsl"
#include "alMathUtil.glsl"
#include "alScreenUtil.glsl"

#define REDUCTION_TYPE		(0) // @@ id="cReductionType" choice = "0,1,2" default = "0"
#define REDUCTION_MAX		(0)
#define REDUCTION_MIN		(1)
#define REDUCTION_CENTER	(2)

#define EDGE_TYPE			(0) // @@ id="cEdgeType" choice = "0,1" default = "0"
#define EDGE_USE_NORMAL 	(0)
#define EDGE_ONLY_DEPTH 	(1)

#define RENDER_TYPE			(0) // @@ id="cRenderType" choice = "0,1,2,3,4,5" default = "0"
#define RENDER_DIRECT		(0)
#define RENDER_REDUCTION 	(1)
#define RENDER_EDGE 		(2)
#define RENDER_MIX 			(3)
#define RENDER_EDGE_BIG		(4)
#define RENDER_EDGE_CONST	(5)


/**
 *	エッジ描画用
 */
BINDING_UBO_OTHER_FIRST uniform EdgeEffect
{
	float   cTanFovyHalf;
	float	cNear;
	float	cRange;	     // == (far - near)
	float   cDepthEdge;
	float   cNormalEdge;
	float   cInvWidth;    
	float   cInvHeight;   
	float	cInvWidthNrm;
	float	cInvHeightNrm;
	float	cEdgeEndDepth;
	float	cEdgePowerMin;
	vec4	cColorOffset;
	vec4	cViewMtx[3];
};

BINDING_UBO_OTHER_SECOND uniform Reduction
{
	float   cInvWidthReduction; 
	float   cInvHeightReduction;
};

BINDING_SAMPLER_NORMAL
uniform sampler2D cWorldNormal;

BINDING_SAMPLER_DEPTH
uniform sampler2D cViewDepth;

layout(binding = 13)
uniform sampler2D cTextureEdge;

/**---------------------------------------
 *	頂点シェーダ
 */
#if defined( AGL_VERTEX_SHADER )

layout (location = 0) in vec3 aPosition;	// @@ id="_p0" hint="position0"
layout (location = 1) in vec2 aTexCoord1;
out vec2	vTexCoord;

void main( void )
{
	VERTEX_SHADER_QUAD_TRIANGLE__CALC_POS_TEX
}

#elif defined( AGL_FRAGMENT_SHADER )

layout(location = 0)	out vec4 oColor;
in	vec2	vTexCoord;

#if ( RENDER_TYPE == RENDER_DIRECT )

void main()
{
	float w       	= cInvWidth;
	float h       	= cInvHeight;
	float wn		= cInvWidthNrm;
	float hn		= cInvHeightNrm;
	
	float depth0 = texture(cViewDepth, vTexCoord).r;
	if( depth0 >= 1.0 ) discard;
	float depth1 = texture(cViewDepth, vTexCoord + vec2(0.0, -h)).r;
	float depth2 = texture(cViewDepth, vTexCoord + vec2(-w, 0.0)).r;
	float depth3 = texture(cViewDepth, vTexCoord + vec2(w, 0.0)).r;
	float depth4 = texture(cViewDepth, vTexCoord + vec2(0.0, h)).r;

	float e_x = abs(abs(depth1 - depth0) - abs(depth4 - depth0));
	float e_y = abs(abs(depth2 - depth0) - abs(depth3 - depth0));

	float dot_normal = 1.0;
#if ( EDGE_TYPE == EDGE_USE_NORMAL )
	vec3 normal0 = texture(cWorldNormal, vTexCoord).rgb;
	vec3 normal1 = texture(cWorldNormal, vTexCoord + vec2(0.0, -hn)).rgb;
	vec3 normal2 = texture(cWorldNormal, vTexCoord + vec2(-wn, 0.0)).rgb;
	vec3 normal3 = texture(cWorldNormal, vTexCoord + vec2(wn, 0.0)).rgb;
	vec3 normal4 = texture(cWorldNormal, vTexCoord + vec2(0.0, hn)).rgb;

	normal0	= rotMtx33Vec3(cViewMtx, normal0);
	normal1	= rotMtx33Vec3(cViewMtx, normal1);
	normal2	= rotMtx33Vec3(cViewMtx, normal2);
	normal3	= rotMtx33Vec3(cViewMtx, normal3);
	normal4	= rotMtx33Vec3(cViewMtx, normal4);

	normal0 = vec3(normal0.x*2-1, normal0.y*2-1, normal0.z*2-1);
	normal1 = vec3(normal1.x*2-1, normal1.y*2-1, normal1.z*2-1);
	normal2 = vec3(normal2.x*2-1, normal2.y*2-1, normal2.z*2-1);
	normal3 = vec3(normal3.x*2-1, normal3.y*2-1, normal3.z*2-1);
	normal4 = vec3(normal4.x*2-1, normal4.y*2-1, normal4.z*2-1);

	dot_normal = dot(normal0, normal1);
	dot_normal = dot(normal0, normal2) + dot_normal;
	dot_normal = dot(normal0, normal3) + dot_normal;
    dot_normal = dot(normal0, normal4) + dot_normal;
#endif

	float stp_0 = step( dot_normal, cNormalEdge );
	float stp_1 = step( cDepthEdge, e_x );
	float stp_2 = step( cDepthEdge, e_y );
	float stp = clamp01(  stp_0 + stp_1 + stp_2 );

	float edge_power = clamp( 1.0 - ( depth0 / cEdgeEndDepth ),	cEdgePowerMin,  1.0);
	vec4 color = texture(cTextureEdge, vTexCoord);
	vec4 edge_color;
	edge_color.r = color.r * ( 1.0 + cColorOffset.r*edge_power );
	edge_color.g = color.g * ( 1.0 + cColorOffset.g*edge_power );
	edge_color.b = color.b * ( 1.0 + cColorOffset.b*edge_power );
	edge_color.a = 1.0;
	edge_color = clamp01( edge_color );
	oColor = mix( color, edge_color, stp );
}

#elif ( RENDER_TYPE == RENDER_REDUCTION )

void main()
{

#if ( REDUCTION_TYPE == REDUCTION_CENTER )
	oColor = texture(cViewDepth, vTexCoord);
#else
	float w       = cInvWidthReduction;
	float h       = cInvHeightReduction;
	float depth0 = texture(cViewDepth, vTexCoord).r;
	float depth1 = texture(cViewDepth, vTexCoord + vec2(0.0, h)).r;
	float depth2 = texture(cViewDepth, vTexCoord + vec2(w, 0.0)).r;
	float depth3 = texture(cViewDepth, vTexCoord + vec2(w, h)).r;
#if ( REDUCTION_TYPE == REDUCTION_MAX )
	oColor.r = max( max( depth0, depth1 ), max( depth2, depth3 ) );
#else
	oColor.r = min( min( depth0, depth1 ), min( depth2, depth3 ) );
#endif
#endif
}

#elif ( RENDER_TYPE == RENDER_EDGE )

void main()
{
	float w       = cInvWidth;
	float h       = cInvHeight;
	
	float depth0 = texture(cViewDepth, vTexCoord).r;
	if( depth0 >= 1.0 ) discard;
	float depth1 = texture(cViewDepth, vTexCoord + vec2(0.0, -h)).r;
	float depth2 = texture(cViewDepth, vTexCoord + vec2(-w, 0.0)).r;
	float depth3 = texture(cViewDepth, vTexCoord + vec2(w, 0.0)).r;
	float depth4 = texture(cViewDepth, vTexCoord + vec2(0.0, h)).r;

	float e_x = abs(abs(depth1 - depth0) - abs(depth4 - depth0));
	float e_y = abs(abs(depth2 - depth0) - abs(depth3 - depth0));

	float dot_normal = 1.0;
#if ( EDGE_TYPE == EDGE_USE_NORMAL )
	vec3 normal0 = texture(cWorldNormal, vTexCoord).rgb;
	vec3 normal1 = texture(cWorldNormal, vTexCoord + vec2(0.0, -h)).rgb;
	vec3 normal2 = texture(cWorldNormal, vTexCoord + vec2(-w, 0.0)).rgb;
	vec3 normal3 = texture(cWorldNormal, vTexCoord + vec2(w, 0.0)).rgb;
	vec3 normal4 = texture(cWorldNormal, vTexCoord + vec2(0.0, h)).rgb;

	normal0	= rotMtx33Vec3(cViewMtx, normal0);
	normal1	= rotMtx33Vec3(cViewMtx, normal1);
	normal2	= rotMtx33Vec3(cViewMtx, normal2);
	normal3	= rotMtx33Vec3(cViewMtx, normal3);
	normal4	= rotMtx33Vec3(cViewMtx, normal4);

	normal0 = vec3(normal0.x*2-1, normal0.y*2-1, normal0.z*2-1);
	normal1 = vec3(normal1.x*2-1, normal1.y*2-1, normal1.z*2-1);
	normal2 = vec3(normal2.x*2-1, normal2.y*2-1, normal2.z*2-1);
	normal3 = vec3(normal3.x*2-1, normal3.y*2-1, normal3.z*2-1);
	normal4 = vec3(normal4.x*2-1, normal4.y*2-1, normal4.z*2-1);

	dot_normal = dot(normal0, normal1);
	dot_normal = dot(normal0, normal2) + dot_normal;
	dot_normal = dot(normal0, normal3) + dot_normal;
    dot_normal = dot(normal0, normal4) + dot_normal;
#endif

	float stp_0 = step( dot_normal, cNormalEdge );
	float stp_1 = step( cDepthEdge, e_x );
	float stp_2 = step( cDepthEdge, e_y );
	float stp = clamp01(  stp_0 + stp_1 + stp_2 );

	float edge_power = clamp( 1.0 - ( depth0 / cEdgeEndDepth ),	cEdgePowerMin,  1.0);
	vec4 color = texture(cTextureEdge, vTexCoord);
	vec4 edge_color;
	edge_color.r = color.r * ( 1.0 + cColorOffset.r*edge_power );
	edge_color.g = color.g * ( 1.0 + cColorOffset.g*edge_power );
	edge_color.b = color.b * ( 1.0 + cColorOffset.b*edge_power );
	edge_color.a = 1.0;
	edge_color = clamp01( edge_color );
	vec4 other_color;
	other_color.r = 0.0;
	other_color.g = 0.0;
	other_color.b = 0.0;
	other_color.a = 0.0;
	oColor = mix( other_color, edge_color, stp );
}

#elif ( RENDER_TYPE == RENDER_MIX )

void main()
{
	oColor = texture(cViewDepth, vTexCoord);
}

#elif ( RENDER_TYPE == RENDER_EDGE_BIG )

float edgePointDepth( sampler2D tex, in vec2 uv, in float w, in float h )
{
	float depth0 = texture( tex, uv ).r;
	if( depth0 >= 1.0 ) return 0.0;

	float depth1 = texture( tex, uv + vec2(0.0, -h) ).r;
	float depth2 = texture( tex, uv + vec2(-w, 0.0) ).r;
	float depth3 = texture( tex, uv + vec2(w, 0.0) ).r;
	float depth4 = texture( tex, uv + vec2(0.0, h) ).r;

	float e_x = abs(abs(depth1 - depth0) - abs(depth4 - depth0));
	float e_y = abs(abs(depth2 - depth0) - abs(depth3 - depth0));

	float stp_1 = step( cDepthEdge, e_x );
	float stp_2 = step( cDepthEdge, e_y );
	float stp = clamp01( stp_1 + stp_2 );
	return stp;
}

void main()
{
	float w       = cInvWidth;
	float h       = cInvHeight;

	float depth0 = texture(cViewDepth, vTexCoord).r;
	if( depth0 >= 1.0 ) discard;
	
	float stp0 = edgePointDepth( cViewDepth, vTexCoord + vec2(-w, -h) ,	w, h );
	float stp1 = edgePointDepth( cViewDepth, vTexCoord + vec2(-w, 0.0),	w, h );
	float stp2 = edgePointDepth( cViewDepth, vTexCoord + vec2(-w, h),		w, h );
	float stp3 = edgePointDepth( cViewDepth, vTexCoord + vec2(0.0, -h),	w, h );
	float stp4 = edgePointDepth( cViewDepth, vTexCoord + vec2(0.0, 0.0),	w, h );
	float stp5 = edgePointDepth( cViewDepth, vTexCoord + vec2(0.0, h),		w, h );
	float stp6 = edgePointDepth( cViewDepth, vTexCoord + vec2(w, -h),		w, h );
	float stp7 = edgePointDepth( cViewDepth, vTexCoord + vec2(w, -h),		w, h );
	float stp8 = edgePointDepth( cViewDepth, vTexCoord + vec2(w, -h),		w, h );
	float stp = clamp01( stp0 + stp1 + stp2 + stp3 + stp4 + stp5 + stp6 + stp7 + stp8 );

	vec4 color = texture(cTextureEdge, vTexCoord);
	vec4 edge_color;
	edge_color.r = 0.0;
	edge_color.g = 0.0;
	edge_color.b = 0.0;
	edge_color.a = 1.0;
	vec4 other_color;
	other_color.r = 0.0;
	other_color.g = 0.0;
	other_color.b = 0.0;
	other_color.a = 0.0;
	oColor = mix( other_color, edge_color, stp );
}

#elif ( RENDER_TYPE == RENDER_EDGE_CONST )

void main()
{
	float w       	= cInvWidth;
	float h       	= cInvHeight;
	float wn		= cInvWidthNrm;
	float hn		= cInvHeightNrm;
	
	float depth0 = texture(cViewDepth, vTexCoord).r;
	if( depth0 >= 1.0 ) discard;
	float depth1 = texture(cViewDepth, vTexCoord + vec2(0.0, -h)).r;
	float depth2 = texture(cViewDepth, vTexCoord + vec2(-w, 0.0)).r;
	float depth3 = texture(cViewDepth, vTexCoord + vec2(w, 0.0)).r;
	float depth4 = texture(cViewDepth, vTexCoord + vec2(0.0, h)).r;

	float e_x = abs(abs(depth1 - depth0) - abs(depth4 - depth0));
	float e_y = abs(abs(depth2 - depth0) - abs(depth3 - depth0));

	float stp_1 = step( cDepthEdge, e_x );
	float stp_2 = step( cDepthEdge, e_y );
	float stp = clamp01( stp_1 + stp_2 );

	float edge_power = clamp( 1.0 - ( depth0 / cEdgeEndDepth ),	cEdgePowerMin,  1.0);
	vec4 color = texture(cTextureEdge, vTexCoord);
	vec4 edge_color;
	edge_color.r = cColorOffset.r;
	edge_color.g = cColorOffset.g;
	edge_color.b = cColorOffset.b;
	edge_color.a = edge_power;
	vec4 other_color;
	other_color.r = 0.0;
	other_color.g = 0.0;
	other_color.b = 0.0;
	other_color.a = 0.0;
	oColor = mix( other_color, edge_color, stp );
}

#endif

#endif
