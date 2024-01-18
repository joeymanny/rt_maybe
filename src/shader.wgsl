@group(0) @binding(0) var<uniform> cmd: MandelCommands;
@group(0) @binding(1) var<storage> spheres: array<Sphere>;

struct MandelCommands{
    size: vec4<f32>,
    cam: vec4<f32>,
    light: vec4<f32>,
    seed: u32,
}

struct Sphere{
    pos: vec4<f32>,
    material: Material,
}

struct Material{
    col: vec3<f32>,
    roughness: f32,
}
struct HitInfo{
    is_hit: bool,
    dst: f32,
    hit_point: vec3<f32>,
    normal: vec3<f32>,
    material: Material,
}

struct Ray{
    origin: vec3<f32>,
    dir: vec3<f32>,
}

const offset_ray_heading: vec3<f32> = vec3(0.0, 0.0, -1.0);

const void_color: vec3<f32> = vec3(0.0);

const surface_dodge: f32 = 0.1;

const NUM_BOUNCES: u32 = u32(10);

var<private> state: u32;

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    // uint2 numPixels = _ScreenParams.xy;
    // uint2 pixelCoord = i.uv * numPixels;
	// uint pixelIndex = pixelCoord.y * numPixels.x + pixelCoord.x;
	// uint rngState = pixelIndex + Frame * 719393;
    var pixel_index = (pos.y * cmd.size.x) + pos.x;
    state = u32(pixel_index) * u32(719393);
    // state += cmd.seed;

    var newpos = pos.xy;
    newpos.y = cmd.size.y - newpos.y;
    newpos /= cmd.size.xy; // normalize to 0 - 1

    newpos.x = newpos.x
        * (cmd.size.x / cmd.size.y)// account for aspect ratio
        - (cmd.size.x / cmd.size.y / 2.0) // into cartesian units
    ;

    newpos.y = newpos.y
        - 0.5
        // * (cmd.size.y / cmd.size.x)// account for aspect ratio
        // - (cmd.size.y / cmd.size.x / 2.0) // into cartesian units
    ;

    var view_plane_scalar: f32 = tan(cmd.cam.w / 2.0);
    newpos *= view_plane_scalar;

    var new_ray_origin: vec3<f32> = vec3(0.0);

    var new_ray_dir: vec3<f32> = normalize(vec3(newpos.x, newpos.y, 0.0) + offset_ray_heading);

    var ray: Ray = Ray(new_ray_origin, new_ray_dir);

    var col = vec3(0.0);

    for (var n = u32(1); n <= NUM_BOUNCES; n++){
        var min_dst = 100000000.0;
        var best_hit: HitInfo;
        for (var i: u32 = u32(0); i < arrayLength(&spheres); i++){
            let hit = line_sphere_intercect(ray, spheres[i]);
            if hit.is_hit && hit.dst < min_dst{
                min_dst = hit.dst;
                best_hit = hit;
            }
        }
        col += best_hit.material.col; // * sun_occlusion_factor(ray, best_hit);
        ray = Ray(ray.dir * best_hit.dst + best_hit.normal * surface_dodge, mix(reflect(ray.dir, best_hit.normal), normalize(best_hit.normal + random_dir(&state)), best_hit.material.roughness));
    }
    col /= f32(NUM_BOUNCES);
    return vec4<f32>(col, 1.0);
}
fn random_dir(state: ptr<private, u32>) -> vec3<f32>{
    var x = random_value_normal_dist(state);
    var y = random_value_normal_dist(state);
    var z = random_value_normal_dist(state);
    return normalize(vec3(x, y, z));
}
fn random_value_normal_dist(state: ptr<private, u32>) -> f32{
    let theta = 2. * 3.1415926 * random_value(state);
    let rho = sqrt(-2. * log(random_value(state)));
    return rho * cos(theta);
}
fn random_value(state: ptr<private, u32>) -> f32 {
    return f32(next_random(state)) / 4294967295.0;
}
fn next_random(state: ptr<private, u32>) -> u32{
    *state = *state * u32(747796405) + u32(14456682.265 * 200.);
    var result: u32 = ((*state >> ((*state >> u32(28)) + u32(4))) ^ *state) * u32(277803737);
    result = (result >> u32(22)) ^ result;
    return result;
}
// float3 RandomDirection(inout uint state){
//     // Thanks to https://math.stackexchange.com/a/1585996
//     float x = RandomValueNormalDistribution(state);
//     float y = RandomValueNormalDistribution(state);
//     float z = RandomValueNormalDistribution(state);
//     return normalize(float3(x, y, z));
// }


			// PCG (permuted congruential generator). Thanks to:
			// www.pcg-random.org and www.shadertoy.com/view/XlGcRh

			// uint NextRandom(inout uint state)
			// {
			// 	state = state * 747796405 + 2891336453;
			// 	uint result = ((state >> ((state >> 28) + 4)) ^ state) * 277803737;
			// 	result = (result >> 22) ^ result;
			// 	return result;
			// }

			// float RandomValue(inout uint state)
			// {
			// 	return NextRandom(state) / 4294967295.0; // 2^32 - 1
			// }

// float RandomValueNormalDistribution(inout uint state)
// {
// 	// Thanks to https://stackoverflow.com/a/6178290
// 	float theta = 2 * 3.1415926 * RandomValue(state);
// 	float rho = sqrt(-2 * log(RandomValue(state)));
// 	return rho * cos(theta);
// }




fn line_sphere_intercect(ray: Ray, sphere: Sphere,) -> HitInfo {
    var hit_info: HitInfo = HitInfo();
    var offset_ray_origin: vec3<f32> = ray.origin - sphere.pos.xyz;
    var a: f32 = dot(ray.dir, ray.dir);
    var b: f32 = 2.0 * dot(offset_ray_origin, ray.dir);
    var c: f32 = dot(offset_ray_origin, offset_ray_origin) - sphere.pos.w * sphere.pos.w;
    var discriminant: f32 = b * b - 4.0* a * c;
    if discriminant >= 0.0{
        var dst: f32 = (-b - sqrt(discriminant)) / (2.0 * a);

        if dst >= 0.0{
            hit_info.is_hit = true;
            hit_info.dst = dst;
            hit_info.hit_point = ray.origin + ray.dir * dst;
            hit_info.normal = normalize(hit_info.hit_point - sphere.pos.xyz);
            hit_info.material = sphere.material;
        }
    }
    return hit_info;
}

// https://github.com/SebLague/Ray-Tracing/blob/main/Assets/Scripts/Shaders/RayTracing.shader
// 			HitInfo RaySphere(Ray ray, float3 sphereCentre, float sphereRadius)
			// {
			// 	HitInfo hitInfo = (HitInfo)0;
			// 	float3 offsetRayOrigin = ray.origin - sphereCentre;
			// 	// From the equation: sqrLength(rayOrigin + rayDir * dst) = radius^2
			// 	// Solving for dst results in a quadratic equation with coefficients:
			// 	float a = dot(ray.dir, ray.dir); // a = 1 (assuming unit vector)
			// 	float b = 2 * dot(offsetRayOrigin, ray.dir);
			// 	float c = dot(offsetRayOrigin, offsetRayOrigin) - sphereRadius * sphereRadius;
			// 	// Quadratic discriminant
			// 	float discriminant = b * b - 4 * a * c; 

			// 	// No solution when d < 0 (ray misses sphere)
			// 	if (discriminant >= 0) {
			// 		// Distance to nearest intersection point (from quadratic formula)
			// 		float dst = (-b - sqrt(discriminant)) / (2 * a);

			// 		// Ignore intersections that occur behind the ray
			// 		if (dst >= 0) {
			// 			hitInfo.didHit = true;
			// 			hitInfo.dst = dst;
			// 			hitInfo.hitPoint = ray.origin + ray.dir * dst;
			// 			hitInfo.normal = normalize(hitInfo.hitPoint - sphereCentre);
			// 		}
			// 	}
			// 	return hitInfo;
			// }


var<private> points: array<array<vec2<f32>, 2>, 3> = array<array<vec2<f32>, 2>, 3>(
    array<vec2<f32>, 2>(vec2(-1.), vec2(-1.)),
    array<vec2<f32>, 2>(vec2<f32>(-1.0, 1.0), vec2<f32>(1., -1.)),
    array<vec2<f32>, 2>(vec2(1.), vec2(1.)),
);
@vertex
fn vs_main(@builtin(vertex_index) in_vertex_index: u32, @builtin(instance_index) instance_index: u32) -> @builtin(position) vec4<f32> {
    return vec4<f32>(points[in_vertex_index][instance_index], 0.0, 1.0); // ITS A FUCKING SQUARE WHAT MORE DO YOU WANT FROM ME
}