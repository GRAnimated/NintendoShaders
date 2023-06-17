/**
 * @file	alPointSprite2D.glsl
 * @author	Tatsuya Kurihara  (C)Nintendo
 *
 * @brief	波テクスチャに対して点を打つために使用
 */

#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable // 明示的な場所指定には必要。無いと GPU ハング。
#endif

#include "alMathUtil.glsl"
#include "alDeclareUniformBlockBinding.glsl"
#include "alDefineVarying.glsl"

DECLARE_VARYING(vec4,	vColor);

#define VERTEX_TYPE				(0) // @@ id="cVertexType" choice="0,1" default="0"
#define VERTEX_TYPE_POINTS		(0)
#define VERTEX_TYPE_TRIANGLES	(1)

#define SPRITE_TYPE			(0) // @@ id="cSpriteType"	choice="0,1,2,3"	default="0"
#define SPRITE_TYPE_CIRBLE	(0)
#define SPRITE_TYPE_CUBIC 	(1)
#define SPRITE_TYPE_QUAD	(2)
#define SPRITE_TYPE_RING	(3)

#define REPEAT_TYPE			(0) // @@ id="cRepeatType" choice="0,1" default="0"
#define REPEAT_TYPE_DISABLE	(0)
#define REPEAT_TYPE_ENABLE	(1)

//------------------------------------------------------------------------------
// 頂点シェーダ
//------------------------------------------------------------------------------
#if defined(AGL_VERTEX_SHADER)

// aPosition  xyz : world position,  w : point sprite size
layout (location=0) in vec4 aPosition;	// @@ id="_p0" hint="position0"
layout (location=1) in vec4 aColor; // @@ id="_p1" hint="position1"

#define	PointSize	aPosition.w
out vec2 vPos;

void main()
{
	gl_Position.xy = aPosition.xy;
	gl_Position.z  = 0.0;
	gl_Position.w  = 1.0;

	vColor.rgb= aColor.rgb;
	vColor.a = 1.0;
	gl_PointSize = PointSize;
	vPos = gl_Position.xy;
}

//------------------------------------------------------------------------------
// フラグメントシェーダ
//------------------------------------------------------------------------------
#elif defined(AGL_FRAGMENT_SHADER)

in vec2 vPos;
out vec4 oColor;
#define FadeThreshold 0.1
void main ( void )
{
//	float dist = clamp(sqrt((dif.x * dif.x) + (dif.y * dif.y)), 0.0, 1.0);
#if VERTEX_TYPE == VERTEX_TYPE_TRIANGLES
	oColor.rgb = vColor.rgb; 
#else
	vec2 dif = gl_PointCoord - vec2(0.5, 0.5);
	float dist2 = (dif.x * dif.x) + (dif.y * dif.y);
#if ( SPRITE_TYPE == SPRITE_TYPE_CIRBLE)
	oColor.rgb = vColor.rgb * (clamp(1.0 - dist2 * 4.0, 0.0, 1.0));// 円周で0になるよう距離減衰
#elif ( SPRITE_TYPE == SPRITE_TYPE_CUBIC)
// 3次式テスト
	float dist = sqrt(dist2);
	if(dist > 0.5) discard;
	dist = dist * 2;
	oColor.rgb = vColor.rgb * (8 * dist*dist*dist - 9 * dist*dist + 1);
#elif ( SPRITE_TYPE == SPRITE_TYPE_QUAD)
// 4次式テスト
	float dist = sqrt(dist2);
	if(dist > 0.5) discard;
	dist = dist * 2;
	oColor.rgb = vColor.rgb * -(-15.0*dist*dist*dist*dist + 32.0*dist*dist*dist - 18.0*dist*dist + 1.0);
#elif ( SPRITE_TYPE == SPRITE_TYPE_RING)
// リング
	float dist = sqrt(dist2);
	if(dist > 0.5) discard;
	dist = dist * 2;
	oColor.rgb = vColor.rgb * (clamp(sin(-dist * 2 * PI),0,1));
#endif
	oColor.a = vColor.a;

// 端付近でフェードアウトさせる
#if REPEAT_TYPE == REPEAT_TYPE_DISABLE
	float rate = (FadeThreshold - clamp01(max(abs(vPos.x), abs(vPos.y)) - (0.99 - FadeThreshold))) * (1.0 / FadeThreshold);
	oColor.rgb = oColor.rgb * rate;
#endif

#endif //VERTEX_TYPE
}

#endif // AGL_FRAGMENT_SHADER

