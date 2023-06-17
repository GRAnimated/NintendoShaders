/**
 * @file	alShadowMask.glsl
 * @author	Yosuke Mori @ aglShadowMaskのカスタマイズ  (C)Nintendo
 *
 * @brief	シャドウマスク
 */

#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable
#endif

#define SM_PRIM_TYPE       ( 0 )	// @@ id="cSmPrimType" choice="1,2,3,4"	default="1"
#define SM_EDGE_TYPE       ( 0 )	// @@ id="cSmEdgeType" choice="0,1"	default="0" 
#define SM_DUMP_TYPE       ( 1 )	// @@ id="cSmDumpType" choice="0,1"	default="1" 
#define SM_IS_FIXED_INTENSITY ( 0 )	// @@ id="cSmIsFixedIntensity" choice="0,1"	default="0" 

#define RENDER_TYPE				(0)		// @@ id="cRenderType" choice="0,1,2,3" default="0"
#define RENDER_TYPE_SHADOW		(0)
#define RENDER_TYPE_AO			(1)
#define RENDER_TYPE_LBUFADD		(2)
#define RENDER_TYPE_LBUFSCALE	(3)

#define SM_IS_SUB_TEX2 	( 0 )	// @@ id="cSmIsSubTex2" choice="0,1"	default="0" 

#define SM_PRIM_TYPE_QUADFILL	0
#define SM_PRIM_TYPE_SPHERE		1
#define SM_PRIM_TYPE_CYLINDER	2
#define SM_PRIM_TYPE_CUBE		3
#define SM_PRIM_TYPE_TEX_CUBE	4
#define SM_PRIM_TYPE_TEX2_CUBE	5

#define SM_EDGE_TYPE_NONE		0
#define SM_EDGE_TYPE_FIX		1

#define SM_DUMP_TYPE_NONE		0
#define SM_DUMP_TYPE_POWER		1

#include "alDeclareUniformBlockBinding.glsl"

#define USING_SCREEN_AND_TEX_COORD_CALC	(1)
#include "alDefineVarying.glsl"
#include "alDeclareMdlEnvView.glsl"

BINDING_UBO_OTHER_FIRST uniform Common // @@ id="cCommon"	
{
    float cDensity;				// (quadのみ)影の濃さ	@todo 全画面塗りつぶしシェーダ—とともに消す
    vec4  cUvOffset;			// xy:uvベース加算値 zw:隣のピクセルへのオフセット
};

#include "alDefineSampler.glsl"
#include "alMathUtil.glsl"

BINDING_SAMPLER_DEPTH uniform sampler2D cLinearDepth;

#if defined( AGL_FRAGMENT_SHADER )
layout(location = 0)	out vec4 oColor;	// ShadowBufferのg成分にシャドウ/r成分にAOを描く
#endif

//========================================
// 球シャドウシェーダー
// * 中心は(0,0,0)で、半径は 0.5 です。 from aglPrimitiveShape.h
//========================================
#if (SM_PRIM_TYPE == SM_PRIM_TYPE_SPHERE )

// 実際にuniform blockのメンバがバリエーションで切られたシェーダ内で使用されていない場合は、そのUniformBlockはUniformBlockSymbolに含まれない。
BINDING_UBO_OTHER_SECOND uniform SphereBlock
{
	vec4  cSphereViewProj[ 4 ];		// ビュープロジェクション行列
	vec3  cViewPosition;			// (球のみ)ビュー座標系の位置
	float cInvRadius;				// (球のみ)半径の逆数
	vec4  cSphereColor;
	float cSphereExp;
};

//------------------------------------------------------------------------------
#if defined( AGL_VERTEX_SHADER )

layout( location = 0 ) in vec3 aPosition;

void main( void ) 
{
	// 半径
    vec4 pos =vec4( aPosition.xyz, 1.0 );
    
    gl_Position.x = dot( cSphereViewProj[ 0 ], pos );
    gl_Position.y = dot( cSphereViewProj[ 1 ], pos );
    gl_Position.z = dot( cSphereViewProj[ 2 ], pos );
    gl_Position.w = dot( cSphereViewProj[ 3 ], pos );
	
	calcScreenAndTexCoord();
}

//------------------------------------------------------------------------------
#elif defined( AGL_FRAGMENT_SHADER )


float getLitPow( vec2 texCoord )
{
	vec3 pos_v;
	pos_v.z = texture( cLinearDepth, texCoord ).r;

	pos_v.z = -( pos_v.z * cRange + cNear );
	pos_v.xy = vScreen * pos_v.z;

	float brightness = 0;//1-cDensity;
	{
		vec3 dir = pos_v - cViewPosition;
		float dist = sqrt( dot( dir, dir ) );
		float distance_dump = clamp01( dist * cInvRadius );
		distance_dump = pow( distance_dump, cSphereExp );
		float intensity = 1.0 - distance_dump;
		brightness = clamp01( brightness + intensity );
	}
	return brightness;
}

void main( void ) 
{
	float brightness = 0;

	brightness += getLitPow( vTexCoord + cUvOffset.xy ) ;

#if (SM_EDGE_TYPE == SM_EDGE_TYPE_FIX )
	brightness += getLitPow( vTexCoord + vec2(cUvOffset.z,           0) + cUvOffset.xy );
	brightness += getLitPow( vTexCoord + vec2(          0, cUvOffset.w) + cUvOffset.xy );
	brightness += getLitPow( vTexCoord + vec2(cUvOffset.z, cUvOffset.w) + cUvOffset.xy );
	brightness *= 0.25;
#endif

	// brightness は暗いところほど 1 影じゃないところは 0
#if (RENDER_TYPE == RENDER_TYPE_SHADOW)
	vec3 color = mix(vec3(1.0), cSphereColor.rgb, brightness);
	oColor = vec4(color.r, color.r, 1.0, 1.0);
#elif (RENDER_TYPE == RENDER_TYPE_AO)
	vec3 color = mix(vec3(1.0), cSphereColor.rgb, brightness);
	oColor = vec4(1.0, color.r, 1.0, 1.0);
#elif (RENDER_TYPE == RENDER_TYPE_LBUFADD)
	oColor = vec4(cSphereColor.rgb, brightness);
#elif (RENDER_TYPE == RENDER_TYPE_LBUFSCALE)
	vec3 color = mix(vec3(1.0), cSphereColor.rgb, brightness);
	oColor = vec4(color, 1.0);
#endif
}

#endif


//========================================
// 円柱シャドウシェーダー
// * 底面は(0,-0.5,0)を中心とする半径0.5でxz軸に平行な円です。y方向の高さは 1 です。
//========================================
#elif (SM_PRIM_TYPE == SM_PRIM_TYPE_CYLINDER )

BINDING_UBO_OTHER_SECOND uniform CylinderBlock
{
	vec4  cCylinderViewProj[ 4 ];	// ビュープロジェクション行列
	vec4  cInvWorldView[ 4 ];		// ワールドビュー逆行列
	vec4  cCylinderColor;
	float cCylinderExpXZ;
	float cCylinderExpY;
	float cCylinderDistYBase;
};

//------------------------------------------------------------------------------
#if defined( AGL_VERTEX_SHADER )

layout( location = 0 ) in vec3 aPosition;

void main( void ) 
{
	// 半径
    vec4 pos =vec4( aPosition.xyz, 1.0 );
    
    gl_Position.x = dot( cCylinderViewProj[ 0 ], pos );
    gl_Position.y = dot( cCylinderViewProj[ 1 ], pos );
    gl_Position.z = dot( cCylinderViewProj[ 2 ], pos );
    gl_Position.w = dot( cCylinderViewProj[ 3 ], pos );

	calcScreenAndTexCoord();
}

//------------------------------------------------------------------------------
#elif defined( AGL_FRAGMENT_SHADER )

float getLitPow( vec2 texCoord )
{
    vec4 pos_v;
    pos_v.z = texture( cLinearDepth, texCoord ).r;

    pos_v.z = -( pos_v.z * cRange + cNear );
    pos_v.xy = vScreen * pos_v.z;
    pos_v.w = 1;

    vec3 lc_pos;
    lc_pos.x = dot( cInvWorldView[ 0 ], pos_v );
    lc_pos.y = dot( cInvWorldView[ 1 ], pos_v );
    lc_pos.z = dot( cInvWorldView[ 2 ], pos_v );
    float brightness = 0;
    {
        vec3 dir = lc_pos;
        dir.y = 0;
        float distXZ = sqrt( dot( dir, dir ) );
#if( SM_IS_FIXED_INTENSITY == 0)
		float distY = lc_pos.y - cCylinderDistYBase;
		distY = abs( distY )/( 0.5 + (step(distY,0)*2-1)*cCylinderDistYBase );
#else
		float distY = abs(lc_pos.y) / 0.5;
#endif
		// シリンダの座標系で減衰するので距離をそのまま
        float distance_dumpXZ = clamp01( distXZ * 2.0 );	// 元の計算に合わせるために*2
		float distance_dumpY  = clamp01( distY );
        distance_dumpXZ = pow( distance_dumpXZ, cCylinderExpXZ );
        distance_dumpY  = pow( distance_dumpY,  cCylinderExpY  );

		float intensity = ( 1.0 - distance_dumpXZ )*( 1.0 - distance_dumpY );
        brightness = clamp01( brightness + intensity );
        
		// 高さが範囲外なら０にする
		brightness *= 1.0 - step(0.5, abs(lc_pos.y));
    }
    return brightness;
}

void main( void ) 
{
	float brightness = 0;

	brightness += getLitPow( vTexCoord + cUvOffset.xy ) ;

#if (SM_EDGE_TYPE == SM_EDGE_TYPE_FIX )
	brightness += getLitPow( vTexCoord + vec2(cUvOffset.z,           0) + cUvOffset.xy );
	brightness += getLitPow( vTexCoord + vec2(          0, cUvOffset.w) + cUvOffset.xy );
	brightness += getLitPow( vTexCoord + vec2(cUvOffset.z, cUvOffset.w) + cUvOffset.xy );
	brightness *= 0.25;
#endif

	// brightness は暗いところほど 1 影じゃないところは 0
#if (RENDER_TYPE == RENDER_TYPE_SHADOW)
	vec3 color = mix(vec3(1.0), cCylinderColor.rgb, brightness);
	oColor = vec4(1.0, color.r, 1.0, 1.0);
#elif (RENDER_TYPE == RENDER_TYPE_AO)
	vec3 color = mix(vec3(1.0), cCylinderColor.rgb, brightness);
	oColor = vec4(color.r, color.r, 1.0, 1.0);
#elif (RENDER_TYPE == RENDER_TYPE_LBUFADD)
	oColor = vec4(cCylinderColor.rgb, brightness);
#elif (RENDER_TYPE == RENDER_TYPE_LBUFSCALE)
	vec3 color = mix(vec3(1.0), cCylinderColor.rgb, brightness);
	oColor = vec4(color, 1.0);
#endif
}

#endif	// #elif defined( AGL_FRAGMENT_SHADER )


//========================================
// キューブシェーダー
// * 中心は(0,0,0)で、各辺は、x,y,z軸のいずれかに平行で、長さが 1 です。
//========================================
#elif (SM_PRIM_TYPE == SM_PRIM_TYPE_CUBE || SM_PRIM_TYPE == SM_PRIM_TYPE_TEX_CUBE || SM_PRIM_TYPE == SM_PRIM_TYPE_TEX2_CUBE )

BINDING_UBO_OTHER_SECOND uniform CubeBlock
{
	vec4	cCubeViewProj[ 4 ];		// ビュープロジェクション行列
	vec4	cCubeInvWorldView[ 4 ];	// ワールドビュー逆行列
	vec4	cCubeProjTexMtx[ 4 ];	// 投影用行列
	vec4	cCubeProjTex2Mtx[ 4 ];	// 投影用行列
	vec4	cCubeColor;
	float	cCubeExpX;
	float	cCubeExpY;
	float	cCubeExpZ;
	float	cCubeDistYBase;
	vec2	cProjTexOffset;
	vec2	cProjTex2Offset;
	vec2	cProjTexScale;
};

//------------------------------------------------------------------------------
#if defined( AGL_VERTEX_SHADER )

layout( location = 0 ) in vec3 aPosition;

void main( void ) 
{
	// 半径
    vec4 pos =vec4( aPosition.xyz, 1.0 );
    
    gl_Position.x = dot( cCubeViewProj[ 0 ], pos );
    gl_Position.y = dot( cCubeViewProj[ 1 ], pos );
    gl_Position.z = dot( cCubeViewProj[ 2 ], pos );
    gl_Position.w = dot( cCubeViewProj[ 3 ], pos );
#if (SM_PRIM_TYPE == SM_PRIM_TYPE_TEX_CUBE)
    float sign_w = sign(gl_Position.w);
    float abs_w  = abs(gl_Position.w);
    
    abs_w = max( abs_w, 32 );
    gl_Position.w = sign_w*abs_w;
#endif
	calcScreenAndTexCoord();
}

//------------------------------------------------------------------------------
#elif defined( AGL_FRAGMENT_SHADER )

float getLitPow( vec2 texCoord )
{
    vec4 pos_v;
    pos_v.z = texture( cLinearDepth, texCoord ).r;

    pos_v.z = -( pos_v.z * cRange + cNear );
    pos_v.xy = vScreen * pos_v.z;
    pos_v.w = 1;

    vec3 lc_pos; // ローカル座標
    lc_pos.x = dot( cCubeInvWorldView[ 0 ], pos_v );
    lc_pos.y = dot( cCubeInvWorldView[ 1 ], pos_v );
    lc_pos.z = dot( cCubeInvWorldView[ 2 ], pos_v );
    float brightness = 0;
   {
		vec3 dir = lc_pos;
		float distX = abs(dir.x);

#if( SM_IS_FIXED_INTENSITY == 0)
		float distY = lc_pos.y - cCubeDistYBase;
		distY = abs( distY )/( 0.5 + (step(distY,0)*2-1)*cCubeDistYBase );
#else
		float distY = abs(lc_pos.y) / 0.5;
#endif

		float distZ = abs(dir.z);
		float distance_dumpX = clamp01( distX * 2.0 );
		float distance_dumpY = clamp01( distY );
		float distance_dumpZ = clamp01( distZ * 2.0 );
	#if (SM_DUMP_TYPE == SM_DUMP_TYPE_POWER)
		distance_dumpX = pow( distance_dumpX, cCubeExpX );
		distance_dumpY = pow( distance_dumpY, cCubeExpY );
		distance_dumpZ = pow( distance_dumpZ, cCubeExpZ );
	#endif // SM_DUMP_TYPE == SM_DUMP_TYPE_POWER
		float intensity = ( 1.0 - distance_dumpX )*( 1.0 - distance_dumpZ )*( 1.0 - distance_dumpY );
		brightness = clamp01( brightness + intensity );
    }
    return brightness;
}

#if (SM_PRIM_TYPE == SM_PRIM_TYPE_TEX_CUBE || SM_PRIM_TYPE == SM_PRIM_TYPE_TEX2_CUBE )
BINDING_SAMPLER_UNIFORM0 uniform sampler2D cProjTex;

/**
 * ライトの強さを取得(投影テクスチャあり)
 */
float getLitPowTex( vec2 texCoord )
{
	vec4 pos_v;
	pos_v.z = texture( cLinearDepth, texCoord ).r;

	pos_v.z = -( pos_v.z * cRange + cNear );
	pos_v.xy = vScreen * pos_v.z;
	pos_v.w = 1;

	vec3 proj_pos;
	proj_pos.x = dot( cCubeProjTexMtx[ 0 ], pos_v );
	proj_pos.y = dot( cCubeProjTexMtx[ 1 ], pos_v );
	proj_pos.z = dot( cCubeProjTexMtx[ 2 ], pos_v );

	// 投影テクスチャを反映
	vec2 tex_pos = proj_pos.xz + vec2(0.5);// 0.5 たしているのは [-1,1] => [0,1] とするため
	tex_pos.x += cProjTexOffset.x;
	tex_pos.y += cProjTexOffset.y;

	tex_pos.x *= cProjTexScale.x;
	tex_pos.y *= cProjTexScale.y;

	float proj_tex = texture( cProjTex, tex_pos ).r;
	#if (SM_PRIM_TYPE == SM_PRIM_TYPE_TEX2_CUBE)
	{
		vec3 proj_pos2;
		proj_pos2.x = dot( cCubeProjTex2Mtx[ 0 ], pos_v );
		proj_pos2.y = dot( cCubeProjTex2Mtx[ 1 ], pos_v );
		proj_pos2.z = dot( cCubeProjTex2Mtx[ 2 ], pos_v );

		vec2 tex_pos2	= proj_pos2.xz + vec2(0.5);
		tex_pos2.x += cProjTex2Offset.x;
		tex_pos2.y += cProjTex2Offset.y;
		tex_pos2.x *= cProjTexScale.x;
		tex_pos2.y *= cProjTexScale.y;
		// 0 の方が明るいらしい
		#if (SM_IS_SUB_TEX2 == 1)
		{
			float new_tex = texture(cProjTex, tex_pos2).r;
			proj_tex = clamp01(proj_tex + new_tex - 1.0);
		}
		#else
		{
			proj_tex = min(proj_tex, texture(cProjTex, tex_pos2).r);
		}
		#endif
	}
	#endif // SM_PRIM_TYPE == SM_PRIM_TYPE_TEX2_CUBE
	if (proj_tex == 1.0) {
		discard;
	}
	
	float brightness = 0;
	{
		vec3 local_pos;
		local_pos.x = dot( cCubeInvWorldView[ 0 ], pos_v );
		local_pos.y = dot( cCubeInvWorldView[ 1 ], pos_v );
		local_pos.z = dot( cCubeInvWorldView[ 2 ], pos_v );

		vec3 dist = abs( local_pos );
#if( SM_IS_FIXED_INTENSITY == 0)
		dist.y = local_pos.y - cCubeDistYBase;
		dist.y = abs( dist.y ) / ( 0.5 + ( step( dist.y, 0 ) * 2 - 1) * cCubeDistYBase );
#else
		dist.y = dist.y / 0.5;
#endif
		float distance_dumpX = clamp01( dist.x * 2.0 );
		float distance_dumpY = clamp01( dist.y );
		float distance_dumpZ = clamp01( dist.z * 2.0 );

	#if (SM_DUMP_TYPE == SM_DUMP_TYPE_POWER)
		distance_dumpX = pow( distance_dumpX, cCubeExpX );
		distance_dumpY = pow( distance_dumpY, cCubeExpY );
		distance_dumpZ = pow( distance_dumpZ, cCubeExpZ );
		float intensity = ( 1.0 - distance_dumpX )*( 1.0 - distance_dumpZ )*( 1.0 - distance_dumpY );
	#else
		float intensity = ( 1.0 - distance_dumpX )*( 1.0 - distance_dumpZ )*( 1.0 - distance_dumpY );
		intensity = 1 - step( 1, 1 - intensity );
	#endif // SM_DUMP_TYPE == SM_DUMP_TYPE_POWER
		brightness = clamp01( brightness + intensity );
	}

	brightness *= 1.0 - proj_tex; 

	return brightness;
}
#endif// SM_PRIM_TYPE == SM_PRIM_TYPE_TEX_CUBE || SM_PRIM_TYPE == SM_PRIM_TYPE_TEX2_CUBE

void main( void ) 
{
	float brightness = 0;
	vec3 color = vec3(1.0);
	#if (SM_PRIM_TYPE == SM_PRIM_TYPE_TEX_CUBE || SM_PRIM_TYPE == SM_PRIM_TYPE_TEX2_CUBE)
	{
		brightness += getLitPowTex( vTexCoord + cUvOffset.xy ) ;
#if (RENDER_TYPE == RENDER_TYPE_SHADOW)
		color = mix(color, cCubeColor.rgb, brightness);
		oColor = vec4(1.0, color.r, 1.0, 1.0);
#elif (RENDER_TYPE == RENDER_TYPE_AO)
		color = mix(color, cCubeColor.rgb, brightness);
		oColor = vec4(color.r, color.r, 1.0, 1.0);
#elif (RENDER_TYPE == RENDER_TYPE_LBUFADD)
		oColor = vec4(cCubeColor.rgb, brightness);
#elif (RENDER_TYPE == RENDER_TYPE_LBUFSCALE)
		color = mix(color, cCubeColor.rgb, brightness);
		oColor = vec4(color, 1.0);
#endif
	}
	#else
	{
		brightness += getLitPow( vTexCoord + cUvOffset.xy ) ;

		#if (SM_EDGE_TYPE == SM_EDGE_TYPE_FIX )
		{
			brightness += getLitPow( vTexCoord + vec2(cUvOffset.z,           0) + cUvOffset.xy );
			brightness += getLitPow( vTexCoord + vec2(          0, cUvOffset.w) + cUvOffset.xy );
			brightness += getLitPow( vTexCoord + vec2(cUvOffset.z, cUvOffset.w) + cUvOffset.xy );
			brightness *= 0.25;
		}
		#endif// SM_EDGE_TYPE == SM_EDGE_TYPE_FIX
		// brightness は暗いところほど 1 影じゃないところは 0
#if (RENDER_TYPE == RENDER_TYPE_SHADOW)
		color = mix(color, cCubeColor.rgb, brightness );
		oColor = vec4(1.0, color.r, 1.0, 1.0);
#elif (RENDER_TYPE == RENDER_TYPE_AO)
		color = mix(color, cCubeColor.rgb, brightness );
		oColor = vec4(color.r, color.r, 1.0, 1.0);
#elif (RENDER_TYPE == RENDER_TYPE_LBUFADD)
		oColor = vec4(cCubeColor.rgb, brightness);
#elif (RENDER_TYPE == RENDER_TYPE_LBUFSCALE)
		color = mix(color, cCubeColor.rgb, brightness );
		oColor = vec4(color, 1.0);
#endif
	}
	#endif// SM_PRIM_TYPE == SM_PRIM_TYPE_TEX_CUBE
}

#endif	// #elif defined( AGL_FRAGMENT_SHADER )
#endif	// (SM_PRIM_TYPE == xxx )
