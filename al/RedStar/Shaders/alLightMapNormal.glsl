/**
 * @file	alLightMapNormal.glsl
 * @author	Yosuke Mori  (C)Nintendo
 *
 * @brief	ライトマップ用法線
 */

#define TEXTURE_TYPE				(0)
#define TEXTURE_TYPE_CUBE			(0)
#define TEXTURE_TYPE_SPHERE			(1)

layout(std140) uniform NormalParam
{
	float uSphereSize;
	float uSphereSizeStepInv;
	float uSphereScaleOffset;
	float uCubeRadius;
};

#if defined( AGL_VERTEX_SHADER )

layout( location = 0 ) in vec3 aPosition;

void main( void ) 
{
    gl_Position.xy = 2.0 * aPosition.xy;
    gl_Position.z  = 0.0;
    gl_Position.w  = 1.0;
}

#elif defined( AGL_FRAGMENT_SHADER )

layout( location = 0 ) out vec4 output_color;

void main( void ) 
{
	vec4 normal = vec4(0.0);

#if (TEXTURE_TYPE == TEXTURE_TYPE_CUBE)

	normal.x = uCubeRadius;
	normal.y = -gl_FragCoord.y + uCubeRadius - 0.5;
	normal.z = -gl_FragCoord.x + uCubeRadius - 0.5;
	normal = normalize(normal);

	output_color = normal;

#elif (TEXTURE_TYPE == TEXTURE_TYPE_SPHERE)

	normal.x = float(gl_FragCoord.x) * uSphereSizeStepInv - 1.0; // -1 to 1
	normal.y = float(gl_FragCoord.y) * uSphereSizeStepInv - 1.0;

	normal.x = uSphereScaleOffset * normal.x;
	normal.y = -uSphereScaleOffset * normal.y;

	float nxny = normal.x * normal.x + normal.y * normal.y;
	normal.z = 1.0 - nxny;
	normal.z = ( 0.0 <= normal.z ) ? sqrt(normal.z) : 0.0;
	normal = normalize(normal);

	output_color = normal;
#endif
}

#endif
