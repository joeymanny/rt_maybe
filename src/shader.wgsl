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

const view_plane_offset: vec3<f32> = vec3(0.0, 0.0, -1.0);

const void_color: vec3<f32> = vec3(0.0);

const far_clip: f32 = 20.0;

const step_length = .01;

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

    let ray_heading = ray;

    var col: vec3<f32> = void_color;

    var go = true;

    var counter = 0;

    var dist = total_distance(ray);

    while (length(ray) < far_clip && go){
        ray += dist * ray_heading;//+= dist * ray_heading;
        dist = total_distance(ray);
        if dist < 0.0001 {
            col = closest_sphere(ray).col.xyz;
            go = false;
            let points_to_light = normalize(cmd.light.xyz - ray);
            var inner_go = true;
            while (length(ray) < far_clip && inner_go ){
                ray += vec3(points_to_light * step_length);
                dist = dist_excluding_light(ray);
                if dist < 0. {
                    col = col * vec3(0.01);
                    inner_go = false;
                }
            }
            continue;
        }
        if length(cmd.light.xyz - ray) < .1{
            col = vec3(1.0, 0.0, 1.0,);
            go = false;
        }
    }


    return vec4<f32>(col, 1.0);

}

fn total_distance(point: vec3<f32>) -> f32{
    var min = length(point - cmd.light.xyz);
    for(var i: u32 = u32(0); i < arrayLength( &spheres ); i++){
        min = min(min, sphere_sdf(point, spheres[i]));
    }
    return min;
}

fn closest_sphere(point: vec3<f32>) -> Sphere{
    var ans = u32(0);
    var min = sphere_sdf(point, spheres[ans]);
    for (var i = u32(0); i < arrayLength(&spheres); i++){
        let contestant = sphere_sdf(point, spheres[i]);
        if contestant < min{
            min = contestant;
            ans = i;
        }
    }
    return (spheres[ans]);
}

fn dist_excluding_light(point: vec3<f32>) -> f32{
    var min = sphere_sdf(point, spheres[0]);
    for(var i: u32 = u32(1); i < arrayLength( &spheres ); i++){
        min = min(min, sphere_sdf(point, spheres[i]));
    }
    return min;
}

fn sphere_sdf(point: vec3<f32>, sphere: Sphere) -> f32{
    return length(point - sphere.pos.xyz) - sphere.pos.w;
}

struct Complex{
    real: f32,
    imag: f32,
}

fn mandel_iter(in: Complex, c: Complex) -> Complex {
    var ret = sqr(in);
    ret.real += c.real;
    ret.imag += c.imag;
    return ret;
}

fn sqr(in: Complex) -> Complex {
    return Complex(pow(in.real, 2.0) - pow(in.imag, 2.0), f32(2.0) * in.real * in.imag);
}

fn abs_sq(in: Complex) -> f32 {
    return (pow(in.real, 2.0) + pow(in.imag, 2.0));
}

fn mandel(c: Complex) -> u32 {
    var z = Complex(0.0, 0.0);
    var i: u32 = u32(0);
    while (i < u32(round(10.0))){
        i += u32(1);
        z = mandel_iter(z, c);
        if abs_sq(z) > 4.0 {
            return i;
        }
    }
    return i;
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
