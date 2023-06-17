/**
 * @file	alLightMap.glsl
 * @author	Yosuke Mori  (C)Nintendo
 *
 * @brief	ライトマップ
 */

#define LM_TEXTURE_TYPE					(0)
#define LM_TEXTURE_TYPE_CUBE			(0)
#define LM_TEXTURE_TYPE_SPHERE			(1)

#define LM_LIGHT_MAX					32
#define LM_LIGHT_NUM					1

#define LM_RING_ENABLE					(0)

layout(std140) uniform Light
{
    vec4			uLightColor[LM_LIGHT_MAX];
	vec3			uLightDir[LM_LIGHT_MAX];
	float			uLightScale[LM_LIGHT_MAX];
	float			uLightDampPow[LM_LIGHT_MAX];
};

layout(std140) uniform Rim
{
	vec4			uRimColor;
	float			uRimPow;
	float			uRimWidth;
};

layout(std140) uniform LightMip
{
    float          uRoughness;
};

#if defined( AGL_VERTEX_SHADER )

layout( location = 0 ) in vec3 aPosition;
layout( location = 1 ) in vec2 aTexCoord;

out vec2  vTexCoord;

void main( void ) 
{
    gl_Position.xy = 2.0 * aPosition.xy;
    gl_Position.z  = 0.0;
    gl_Position.w  = 1.0;

    vTexCoord = aTexCoord;

#if defined( AGL_TARGET_GL )
    vTexCoord.y = 1.0 - vTexCoord.y;
#endif
}

#elif defined( AGL_FRAGMENT_SHADER )

#include "alMathUtil.glsl"
#include "alLightingFunction.glsl"

uniform sampler2D cNormal;

in vec2 vTexCoord;

layout( location = 0 ) out vec4 output_color[ gl_MaxDrawBuffers ];

void calcHalfVec(out vec3 half_vec, in int light_no, in vec3 light_dir, in vec3 v, in vec3 normal )
{
	NORMALIZE_B(half_vec, v + light_dir);
	vec3 axis = cross(normal, half_vec);
	NORMALIZE_B(axis, axis);
	float rad = uLightScale[ light_no ];
#if (LM_RING_ENABLE == 0)
	float max_rad = acos(clamp01(dot(-half_vec, normal)));
	rad = min(max_rad, rad);
#endif
	float angle = rad * 0.5;
	float angle_c = cos(angle);
	float angle_s = sin(angle);
	vec4 q = vec4(axis.x*angle_s, axis.y*angle_s, axis.z*angle_s, angle_c);
	half_vec = QRotVec(half_vec, q);
}

#define CALC_COLOR(color_no, light_no, intencity, normal, half_vec)						\
{																						\
	float alpha = clamp01(-dot( normal, half_vec ));									\
    vec4 color = vec4(mix(vec3(0.0), uLightColor[ light_no ].rgb, intencity), alpha);	\
	color_no = color_no + color;														\
}

#define calc_cube_map_normal( no, light_no )								\
{																			\
	vec3 light_dir = uLightDir[ light_no ];									\
	vec3 v = -normal_##no;													\
	vec3 half_vec = light_dir;												\
	calcHalfVec( half_vec, light_no, light_dir, v, normal_##no );			\
																			\
    float intencity;														\
    calcSpecularGGXFromDir(intencity, light_dir, half_vec, normal_##no, uRoughness);	\
	CALC_COLOR(color##no, light_no, intencity, normal_##no, half_vec);		\
}

#define calc_sphere_normal( no, normal, light_no )                  \
{                                                                   \
	vec3 light_dir = uLightDir[ light_no ];	                        \
	vec3 v = vec3(0.0, 0.0, -1.0);									\
	vec3 half_vec = light_dir;										\
	calcHalfVec( half_vec, light_no, light_dir, v, normal );		\
																	\
    float intencity;                                                \
    calcSpecularGGXFromDir(intencity, light_dir, half_vec, normal, uRoughness);	\
	CALC_COLOR(color##no, light_no, intencity, normal, half_vec);	\
}

void main( void ) 
{
    vec3 normal = texture( cNormal, vTexCoord ).rgb;

    vec4 color0 = vec4( 0.0 );
    vec4 color1 = vec4( 0.0 );
    vec4 color2 = vec4( 0.0 );
    vec4 color3 = vec4( 0.0 );
    vec4 color4 = vec4( 0.0 );
    vec4 color5 = vec4( 0.0 );

    vec3 normal_0 = vec3(  normal.x,  normal.y, -normal.z );
    vec3 normal_1 = vec3( -normal.x,  normal.y,  normal.z );
    vec3 normal_2 = vec3( -normal.z,  normal.x,  normal.y );
    vec3 normal_3 = vec3( -normal.z, -normal.x, -normal.y );
    vec3 normal_4 = vec3( -normal.z,  normal.y, -normal.x );
    vec3 normal_5 = vec3(  normal.z,  normal.y,  normal.x );

    for ( int i = 0; i < LM_LIGHT_NUM; ++i )
    {
        switch ( LM_TEXTURE_TYPE )
        {
        case LM_TEXTURE_TYPE_SPHERE:
            {
                calc_sphere_normal( 0, normal, i );
                break;
            }
        case LM_TEXTURE_TYPE_CUBE:
            {
                calc_cube_map_normal( 0, i );
                calc_cube_map_normal( 1, i );
                calc_cube_map_normal( 2, i );
                calc_cube_map_normal( 3, i );
                calc_cube_map_normal( 4, i );
                calc_cube_map_normal( 5, i );
                break;
            }
        }
    }


    switch ( LM_TEXTURE_TYPE )
    {
    case LM_TEXTURE_TYPE_SPHERE:
        {
		    vec4 rim = uRimColor * pow( clamp( uRimWidth * ( 1.0 - abs( normal.z ) ), 0.0, 1.0 ), uRimPow );
            output_color[ 0 ] = color0 + rim;
            break;
        }
    case LM_TEXTURE_TYPE_CUBE:
        {
            output_color[ 0 ] = color0;
            output_color[ 1 ] = color1;
            output_color[ 2 ] = color2;
            output_color[ 3 ] = color3;
            output_color[ 4 ] = color4;
            output_color[ 5 ] = color5;
            break;
        }
    }
}

#endif
