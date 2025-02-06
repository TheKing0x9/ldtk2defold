varying mediump vec4 position;
varying mediump vec2 var_texcoord0;

uniform lowp sampler2D texture_sampler;
uniform lowp vec4 tint;

void main()
{
	// Pre-multiply alpha since all runtime textures already are
	lowp vec4 tint_pm = vec4(tint.xyz, 1.0);
	vec4 color = texture2D(texture_sampler, var_texcoord0.xy) * tint_pm;
	
	if (tint.w == 1.0 && color.rgb == vec3(1.0, 1.0, 1.0)) {
		color = vec4(0.0);
	}

	gl_FragColor = color;
}
