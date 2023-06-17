/**
 * @file	alRenderKaleidoscope.glsl
 * @author	Tatsuya Kurihara  (C)Nintendo
 *
 * @brief	万華鏡描画
 */
#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable // 明示的な場所指定には必要。無いと GPU ハング。
#endif

#include "alMathUtil.glsl"
#include "alScreenUtil.glsl"
#include "alDeclareUniformBlockBinding.glsl"

#define USING_SCREEN_AND_TEX_COORD_CALC	(1)
#include "alDefineVarying.glsl"
#include "alDeclareMdlEnvView.glsl"

#define MIRROR_TYPE		(0)
#define MIRROR_TYPE_SIMPLE_QUAD (0)
#define MIRROR_TYPE_CROSS_QUAD  (1)
#define MIRROR_TYPE_TILED_TRIANGLE  (2)
#define MIRROR_TYPE_RADIAL  (3)
#define MIRROR_TYPE_RADIAL_POINT_SYMMETRY  (4)

#define IS_DISTORT (1)



layout( binding = 0 ) uniform sampler2D uOrgColor;

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
}

//------------------------------------------------------------------------------
// フラグメントシェーダ
//------------------------------------------------------------------------------
#elif defined( AGL_FRAGMENT_SHADER )

BINDING_UBO_OTHER_FIRST uniform KaleidoscopeParam // @@ id="cOceanDispToNrmFold" comment="法線＋フォールディング生成パラメータ"
{
	int uDivideNum;
};


vec2 calcCoordSimpleQuadMirror(vec2 sc){
	vec2 ret = sc * 2;
	if(ret.x > 1) ret.x = 1 - (ret.x - 1);
	if(ret.y > 1) ret.y = 1 - (ret.y - 1);
	return ret;
}

vec3 calcColorSimpleQuadMirror(){
	vec2 sc = calcCoordSimpleQuadMirror(getScreenCoord());
	return texture( uOrgColor, sc ).rgb;
}

vec3 calcColorCrossQuadMirror(){
	vec2 sc = calcCoordSimpleQuadMirror(getScreenCoord());
	return 0.5 * (texture( uOrgColor, sc ).rgb + texture( uOrgColor, vec2(sc.y, sc.x) ).rgb);
}

vec3 calcColorTiledTriangle(){
	vec2 sc = getScreenCoord();
	sc.x = clamp(sc.x, 0.5 + sc.y * sin(30.0), 0.5 - sc.y * sin(30.0));
	return texture(uOrgColor, sc).rgb;
}

vec3 calcColorRadial(int div){
	vec2 sc = getScreenCoord();
	// 中心からのベクトルに変換
	sc -= vec2(0.5);
	// 横が長いので調整
	sc.x *= ScrSizeX / ScrSizeY;
	// 距離
	float len = length(sc);
	// 角度
	float angle = degrees(atan(sc.y,sc.x));// + 180.0;
	float div_angle = 360.0 / div;

	vec2 coord;
	coord.y = len;
#if IS_DISTORT == 1
	float start = 0.0;
	if( mod(floor(angle/div_angle), 2) == 0){
		start = 1.0;
	}
	coord.x = mix(start, 1.0 - start, mod(angle, div_angle) / div_angle);
#else
	float s = coord.y * sin(radians(div_angle / 2)) * 0.5;
	if( mod(floor(angle/div_angle), 2) == 0){
		coord.x = mix(0.5 - s, 0.5 + s, mod(angle, div_angle) / div_angle);
	}else{
		coord.x = mix(0.5 + s, 0.5 - s, mod(angle, div_angle) / div_angle);
	}
#endif
	return texture(uOrgColor, coord).rgb;
}

vec3 calcColorRadialPointSymmetry(int div){
	vec2 sc = getScreenCoord();
	// 中心からのベクトルに変換
	sc -= vec2(0.5);
	// 横が長いので調整
	sc.x *= ScrSizeX / ScrSizeY;
	// 距離
	float len = length(sc);
	// 角度
	float angle = degrees(atan(sc.y/sc.x)) + 90;// 0～180になる
	float div_angle = 180.0 / div;

	vec2 coord;
	coord.y = len;

#if IS_DISTORT == 1
	coord.x = mix(0.0, 1.0, mod(angle, div_angle) / div_angle); //mix(-0.5, 0.5, mod(angle, div_angle) / div_angle);
#else
	float s = coord.y * sin(radians(div_angle / 2));
	coord.x = mix(0.5 - s, 0.5 + s, mod(angle, div_angle) / div_angle);
#endif
	return texture(uOrgColor, coord).rgb;
}

// 出力変数
layout( location = 0 )	out vec4 oColor;

void main()
{
	float s_div_x = ScrSizeX / 2;
	float s_div_y = ScrSizeY / 2;

	vec3 org_color;;

#if MIRROR_TYPE == MIRROR_TYPE_SIMPLE_QUAD
	org_color = calcColorSimpleQuadMirror();
#elif MIRROR_TYPE == MIRROR_TYPE_CROSS_QUAD
	org_color = calcColorCrossQuadMirror();
#elif MIRROR_TYPE == MIRROR_TYPE_TILED_TRIANGLE
	org_color = calcColorTiledTriangle();
#elif MIRROR_TYPE == MIRROR_TYPE_RADIAL
	org_color = calcColorRadial(uDivideNum);
#elif MIRROR_TYPE == MIRROR_TYPE_RADIAL_POINT_SYMMETRY
	org_color = calcColorRadialPointSymmetry(uDivideNum);
#endif

	oColor.rgb		= org_color;
	oColor.a 		= 1.0;
}
#endif // defined( AGL_FRAGMENT_SHADER )

