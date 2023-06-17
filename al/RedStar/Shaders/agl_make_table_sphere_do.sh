/**
 *	@file	agl_make_table_sphere_do.sh
 *	@brief	スフィア DO 用のテーブルを 3D テクスチャに描画する
 *	@author	Matsuda Hirokazu
 */

#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable // 明示的な場所指定には必要。無いと GPU ハング。
#endif

#define SAMPLING_NUM	100
#define M_PI			3.1415926535897932384626433832795

uniform float	uTanConeAngle;

#if defined(AGL_VERTEX_SHADER)
/*-----------------------------------------------
 *	頂点シェーダ
 */
layout(location = 0) in vec4 aPosition;
layout(location = 1) in vec2 aTexCoord;
out vec2 vTexCrd;

void main()
{
	gl_Position.xy = 2.0 * aPosition.xy;
	gl_Position.z  = 0.0;
	gl_Position.w  = 1.0;

	vTexCrd = aTexCoord;
#if defined( AGL_TARGET_GL )
	vTexCrd.y = 1.0 - vTexCrd.y;
#endif
}

#elif defined(AGL_FRAGMENT_SHADER)
/*-----------------------------------------------
 *	フラグメントシェーダ
 */
in vec2 vTexCrd;

/**
 *	レイと球の判定
 */
float checkRaySphere(in vec3 ray
					, in float inv_sin_theta_sqr
					, in float cos_phai
					, in float sqrt_inv_cos_phai2)
{
	float ray_len_sqr = dot(ray, ray);
	float edge = ray_len_sqr * inv_sin_theta_sqr;
	float sqrt_step_check = ray.x * sqrt_inv_cos_phai2 + cos_phai;
	return step(edge, sqrt_step_check * sqrt_step_check);
}

void main()
{
	float disk_r = uTanConeAngle;

	const float diff = 1.0/SAMPLING_NUM;
	const float start = 0.5 * diff;
	float r_0_1 = start;
	float t_0_1 = start;
	float min_y = sqrt(1 - disk_r * disk_r);
	float range_y = 1 - min_y;

	float inv_sin_theta_sqr		= 1.0 - vTexCrd.y * vTexCrd.y;
	float cos_phai				= vTexCrd.x;
	float sqrt_inv_cos_phai2	= sqrt(1.0 - cos_phai * cos_phai);
	float hit_sum = 0.0;
	// Spherical Cap 上の一様分布
	for (int r=0; r<SAMPLING_NUM; ++r)
	{
		float u = min_y + range_y * r_0_1;
		float sqrt_inv_u2 = sqrt(1.0 - u*u);
		for (int t=0; t<SAMPLING_NUM; ++t)
		{
			float theta = t_0_1 * M_PI * 2.0;
			float cos = cos(theta);
			float sin = sin(theta);
			vec3 ray = vec3(sqrt_inv_u2 * cos, u, sqrt_inv_u2 * sin);
			hit_sum += checkRaySphere(ray
									, inv_sin_theta_sqr
									, cos_phai
									, sqrt_inv_cos_phai2);
			t_0_1 += diff;
		}
		r_0_1 += diff;
	}
	const float inv_samp_num = 1.0 / (SAMPLING_NUM*SAMPLING_NUM);
	float bl = hit_sum * inv_samp_num;
	gl_FragColor = vec4(bl);
}

#endif // AGL_*_SHADER
