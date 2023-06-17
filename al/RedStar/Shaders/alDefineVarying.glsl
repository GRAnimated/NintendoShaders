/**
 * @file	alDefineVarying.glsl
 * @author	Matsuda Hirokazu  (C)Nintendo
 *
 * @brief	varying 変数の宣言法の定義
 */
#ifndef AL_DEFINE_VARYING_GLSL
#define AL_DEFINE_VARYING_GLSL

#ifndef IS_USING_GEOMETRY_SHADER
	#define IS_USING_GEOMETRY_SHADER	(0)
	// ジオメトリシェーダのソースなのに 0 はコンパイルエラーにしたい
	#if defined( AGL_GEOMETRY_SHADER )
		Error_Need_to_define_IS_USING_GEOMETRY_SHADER
	#endif
#endif


//------------------------------------------------------------------------------
// 頂点シェーダ
//------------------------------------------------------------------------------
#if defined(AGL_VERTEX_SHADER)

#if (IS_USING_GEOMETRY_SHADER == 0)

#define	DECLARE_VARYING(type, var_name)							out type var_name
#define	DECLARE_NOPERS_VARYING(type, var_name)	noperspective	out type var_name
#define getVarying(var_name)	(var_name)

#else

#define	DECLARE_VARYING(type, var_name)	out type var_name##_vs
#define	DECLARE_NOPERS_VARYING(type, var_name)	noperspective out type var_name##_vs
#define getVarying(var_name)	(var_name##_vs)

#endif // IS_USING_GEOMETRY_SHADER

//------------------------------------------------------------------------------
// ジオメトリシェーダ
//------------------------------------------------------------------------------
#elif defined( AGL_GEOMETRY_SHADER )

#define	DECLARE_VARYING(type, var_name)	\
	in	type var_name##_vs[];	\
	out	type var_name##_gs
#define DECLARE_NOPERS_VARYING(type, var_name) \
	in	type var_name##_vs[];	\
	noperspective out	type var_name##_gs

#define getVaryingIn(var_name, index)	(var_name##_vs[index])
#define getVaryingOut(var_name)		(var_name##_gs)

//------------------------------------------------------------------------------
// フラグメントシェーダ
//------------------------------------------------------------------------------
#elif defined(AGL_FRAGMENT_SHADER)

#if (IS_USING_GEOMETRY_SHADER == 0)

#define	DECLARE_VARYING(type, var_name)							in type var_name
#define	DECLARE_NOPERS_VARYING(type, var_name)	noperspective	in type var_name
#define getVarying(var_name)	(var_name)

#else

#define	DECLARE_VARYING(type, var_name)	in type var_name##_gs
#define	DECLARE_NOPERS_VARYING(type, var_name)	noperspective in type var_name##_gs
#define getVarying(var_name)	(var_name##_gs)

#endif // IS_USING_GEOMETRY_SHADER
#endif // (AGL_******_SHADER)

#endif // AL_DEFINE_VARYING_GLSL
