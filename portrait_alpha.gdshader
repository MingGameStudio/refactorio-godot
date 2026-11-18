shader_type canvas_item;

// Suppress faint background residue while keeping a soft silhouette edge.
uniform float transparent_threshold : hint_range(0.0, 0.1) = 0.02;
uniform float opaque_threshold : hint_range(0.11, 1.0) = 0.2;

void fragment() {
	COLOR.a = smoothstep(transparent_threshold, opaque_threshold, COLOR.a);
}
