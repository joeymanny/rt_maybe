@group(0) @binding(0) var<uniform> cmd: MandelCommands;
@group(0) @binding(1) var<storage> spheres: array<Sphere>;
struct MandelCommands{
    size: vec4<f32>,
    cam: vec4<f32>,
    light: vec4<f32>,
}

struct Sphere{
    pos: vec4<f32>,
    col: vec4<f32>,
}

const view_plane_offset: vec3<f32> = vec3(0.0, 0.0, 1.0);

const void_color: vec3<f32> = vec3(0.0);

const surface_dodge: f32 = 0.1;

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {


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

    var ray = normalize(vec3(newpos * view_plane_scalar, 0.0) + view_plane_offset);

    let og_ray = ray;

    var col = vec3(0.);

    var least_dist = 100000000000000000.0;

    var colliding_sphere: i32 = -1;

    var normal: vec3<f32>;

    var dist_intersect:f32;

    // col = vec3(line_circle_intercect(ray, spheres[1]) * 20.0);
    for (var i = u32(0); i < u32(arrayLength(&spheres)); i++){
        dist_intersect = -line_circle_intersect(ray, spheres[i]);
        if (dist_intersect > 0.0 && dist_intersect < least_dist){
            normal = normalize(ray - spheres[i].pos.xyz);
            least_dist = dist_intersect;
            colliding_sphere = i32(i);
        }
    }

    if colliding_sphere > -1{
        col = spheres[colliding_sphere].col.xyz;
        ray += normal * surface_dodge;
        var collision_to_light = 100000000000000000.0;
        for (var i = u32(0); i < u32(arrayLength(&spheres)); i++){
            var s = spheres[i];
            s.pos = vec4(s.pos.xyz - ray, s.pos.w);
            let contestor = -line_circle_intersect(normalize(cmd.light.xyz - ray), s);
            if contestor < collision_to_light{
                collision_to_light = contestor;
            }
        }
        if collision_to_light < 100000000000000000.0{
            col *= 0.3;
        }
    }

    if -line_circle_intersect(og_ray, Sphere(cmd.light, vec4(0.0))) > 0.0{
        col = vec3(1.0, 0.0, 1.0);
    }



    return vec4<f32>(col, 1.0);

}

fn is_line_intersecting_sphere(ray: vec3<f32>, sphere: Sphere) -> bool{
    return line_circle_intersect(ray, sphere) >= 0.0;
}

fn test(param: f32) -> (bool, f32){
    return (false, f32(1.0));
}

// fn line_circle_intersect(ray: vec3<f32>, sphere: Sphere) -> f32{
//     return (pow(dot(ray, (view_plane_offset - sphere.pos.xyz)), 2.0) - (pow(length(view_plane_offset - sphere.pos.xyz), 2.0) - pow(sphere.pos.w, 2.0)));
// }
fn line_circle_intersect(ray: vec3<f32>, sphere: Sphere) -> f32{
    let to_be_sqrt = 
    
            pow(dot(ray, view_plane_offset - sphere.pos.xyz), 2.0)
        
        - pow(length(ray), 2.0) * (pow(length(view_plane_offset - sphere.pos.xyz), 2.0) - pow(sphere.pos.w, 2.0))
        ;
    // if to_be_sqrt < 0.0{
    //     return (to_be_sqrt);
    // }

    return (-(dot(ray, view_plane_offset - sphere.pos.xyz)) 
        + sqrt(to_be_sqrt)
    ) / pow(length(ray), 2.0);
}

var<private> points: array<array<vec2<f32>, 2>, 3> = array<array<vec2<f32>, 2>, 3>(
    array<vec2<f32>, 2>(vec2(-1.), vec2(-1.)),
    array<vec2<f32>, 2>(vec2<f32>(-1.0, 1.0), vec2<f32>(1., -1.)),
    array<vec2<f32>, 2>(vec2(1.), vec2(1.)),
);
@vertex
fn vs_main(@builtin(vertex_index) in_vertex_index: u32, @builtin(instance_index) instance_index: u32) -> @builtin(position) vec4<f32> {
    return vec4<f32>(points[in_vertex_index][instance_index], 0.0, 1.0); // ITS A FUCKING SQUARE WHAT MORE DO YOU WANT FROM ME
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