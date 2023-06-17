/**
 * @file	alDeclareMdlEnvView.glsl
 * @author	Yosuke Mori  (C)Nintendo
 *
 * @brief	環境と視点を合わせたユニフォームブロック 宣言
 */

BINDING_UBO_MDL_ENV_VIEW uniform MdlEnvView     // @@ id="cMdlEnvView"
{
	vec4	cView[3];
	vec4	cInvView[3];
	vec4	cViewProj[4];
	vec4	cInvProjView[3];
	vec4	cInvProj[4];
	// ViewMtx の平行移動成分を除外した変換行列。ワールド座標のレイを計算するのに使う
	vec4	uInvProjViewNoTrans[3];

	float	cInvExposure;
	float	uIrradianceScale;

	// ディレクショナルライト
	vec4	cDirLightViewDirFetchPos;

	// レンダリング情報
	float	cNear;
	float	cFar;
	float	cRange;		// == (far - near)
	float	cInvRange;	// == 1 / (far - near)
	vec2	cTanFovyHalf;	///< tan( fovy / 2 )
	vec2	cScrProjOffset;
	vec4	cScrSize;	// xy : screen size,  zw : inv screen size

	vec3	cCameraPos; // Far のビルボード処理で必要
	vec4	uAlphaMaskProjMtx[4];	//αマスクの投影Mtx

	vec4	cParallaxCubeInvWorldMtx[3];
	vec3	cParallaxCubeCenter;
	vec3	cParallaxCubeHalfSize;

	int		cBayerMtxSize;
	int		cBayerMtx[256];				// @@ id="bayer_mtx" type="int"

	vec4	cPrevView[3];
	vec4	cPrevViewProj[4];

	float	cGlobalLodBias;
	vec2	cDitherScale;

	// ポイントスプライト用
	float 	cInvNearClipWidth;
};

#define ScrSize		cScrSize.xy
#define ScrSizeX	cScrSize.x
#define ScrSizeY	cScrSize.y

#define InvScrSize	cScrSize.zw
#define InvScrSizeX	cScrSize.z
#define InvScrSizeY	cScrSize.w

#define InvNearClipWidth	cInvNearClipWidth

/**
 *	ディレクショナルライトのカラーを取得する
 */
void getDirectionalLightColor(out vec4 color, sampler2D dir_lit_tex)
{
	color = texture(dir_lit_tex, vec2(cDirLightViewDirFetchPos.w, 0.5));
}

#if defined(USING_SCREEN_AND_TEX_COORD_CALC)

DECLARE_NOPERS_VARYING(vec2,	vTexCoord);
DECLARE_NOPERS_VARYING(vec2,	vScreen);

#if defined( AGL_VERTEX_SHADER )


void calcScreenAndTexCoord()
{
	vScreen.xy = gl_Position.xy / gl_Position.w; // -1.0 ~ 1.0

#if defined( AGL_TARGET_GX2 ) || defined( AGL_TARGET_NVN )
	vScreen.y *= -1.0;
#endif

	vTexCoord = vScreen.xy * 0.5 + 0.5; // 0 - 1.0
	vScreen.xy *= -cTanFovyHalf.xy;
	vScreen.xy -= cScrProjOffset.xy;
}

void calcScreenAndTexCoordWithAdjust(in vec2 adjust)
{
	vScreen.xy = gl_Position.xy / gl_Position.w; // -1.0 ~ 1.0

#if defined( AGL_TARGET_GX2 ) || defined( AGL_TARGET_NVN )
	vScreen.y *= -1.0;
#endif

	vTexCoord = vScreen.xy * 0.5 + 0.5; // 0 - 1.0
	vTexCoord += adjust;
	vScreen.xy *= -cTanFovyHalf.xy;
	vScreen.xy -= cScrProjOffset.xy;
}

#elif defined( AGL_FRAGMENT_SHADER )

#define getScreenCoord() (getVarying(vTexCoord))
#define getScreenRay()   (getVarying(vScreen))

#endif // defined(USING_SCREEN_AND_TEX_COORD_CALC)

#if 0
/**
 *	自動露出補正の値取得。
 */
float getExposure()
{
	return (1.0 / texture(uExposureTexture, vec2(0.0)).a) * cInvExposure;
}
#endif

#endif
