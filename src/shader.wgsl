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

    var col = vec3(0.);

    var least_dist = 100000000000000000.0;

    var colliding_sphere: u32;

    // col = vec3(line_circle_intercect(ray, spheres[1]) * 20.0);
    for (var i = u32(0); i < u32(arrayLength(&spheres)); i++){
        let dist_intersect = line_circle_intersect(ray, spheres[i]);
        if (dist_intersect > 0.0 && dist_intersect < least_dist){
            least_dist = dist_intersect;
            col = spheres[i].col.xyz;
            colliding_sphere = i;
        }
    }



    return vec4<f32>(col, 1.0);

}

fn is_line_intersecting_sphere(ray: vec3<f32>, sphere: Sphere) -> bool{
    return line_circle_intersect(ray, sphere) >= 0.0;
}

// fn line_circle_intersect(ray: vec3<f32>, sphere: Sphere) -> f32{
//     return (pow(dot(ray, (view_plane_offset - sphere.pos.xyz)), 2.0) - (pow(length(view_plane_offset - sphere.pos.xyz), 2.0) - pow(sphere.pos.w, 2.0)));
// }
fn line_circle_intersect(ray: vec3<f32>, sphere: Sphere) -> f32{
    let to_be_sqrt = 
    
            pow(dot(ray, view_plane_offset - sphere.pos.xyz), 2.0)
        
        - pow(length(ray), 2.0) * (pow(length(view_plane_offset - sphere.pos.xyz), 2.0) - pow(sphere.pos.w, 2.0))
        ;
    if to_be_sqrt < 0.0{
        return to_be_sqrt;
    }

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
