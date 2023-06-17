/**
 * @file	alComposeLightMap.glsl
 * @author	Yosuke Mori  (C)Nintendo
 *
 * @brief	キューブマップ合成ライトマップ
 */
#define IS_USE_TEXTURE_BIAS ( 0 )

#include "alDeclareUniformBlockBinding.glsl"
#include "alCubeMapDrawUtil.glsl"
#include "alMathUtil.glsl"

uniform samplerCube cTexLightMap;
uniform samplerCube cTexCubeMap;

layout( std140 ) uniform Roughness
{
	float	uRoughness;
};

#if defined( AGL_VERTEX_SHADER )

layout( location = 0 ) in vec3 aPosition;
out	vec3	vRay[ 6 ];

void main( void ) 
{
    gl_Position.xy = 2.0 * aPosition.xy;
    gl_Position.z  = 0.0;
    gl_Position.w  = 1.0;

	vec4 pos = vec4( gl_Position.xy, 1.0, 1.0 );

	vRay[ 0 ] = multMtx44Vec4( uProjViewInvPosX, pos ).xyz;
	vRay[ 1 ] = multMtx44Vec4( uProjViewInvNegX, pos ).xyz;
	vRay[ 2 ] = multMtx44Vec4( uProjViewInvPosY, pos ).xyz;
	vRay[ 3 ] = multMtx44Vec4( uProjViewInvNegY, pos ).xyz;
	vRay[ 4 ] = multMtx44Vec4( uProjViewInvPosZ, pos ).xyz;
	vRay[ 5 ] = multMtx44Vec4( uProjViewInvNegZ, pos ).xyz;
}

#elif defined( AGL_FRAGMENT_SHADER )

#include "alHdrUtil.glsl"
#include "alFetchCubeMap.glsl"

in	vec3	vRay[ 6 ];
out vec4	oColor[ 6 ];

void main( void ) 
{
	for( int f = 0; f < 6; ++f )
	{
		vec4 cube_color = vec4( 0.0 );
        fetchCubeMapConvertHdr( cube_color, cTexCubeMap, vRay[ f ], 5.0 * uRoughness );

		vec4 lightmap_color;
		fetchCubeMap( lightmap_color, cTexLightMap, vRay[ f ], sqrt( uRoughness ) * 5.0 );
		vec4 final_color = cube_color + lightmap_color;

		// LDRに圧縮
		CalcHdrToLdr( oColor[ f ], final_color );
	}
}

#endif
