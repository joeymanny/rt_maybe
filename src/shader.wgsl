@group(0) @binding(0) var<uniform> cmd: MandelCommands;

struct MandelCommands{
    size: vec2<f32>,
    circle_pos: vec2<f32>,
    circle_rad: f32,
}


@vertex
fn vs_main(@builtin(vertex_index) in_vertex_index: u32, @builtin(instance_index) instance_index: u32) -> @builtin(position) vec4<f32> {
    // let x = f32(i32(in_vertex_index) - 1);
    // let y = f32(i32(in_vertex_index & 1u) * 2 - 1);
    var x: f32 = 0.0;
    var y: f32 = 0.0;
    // square
    if in_vertex_index == u32(0){
        x = -1.;
        y = -1.;
    } else if in_vertex_index == u32(1){
        if instance_index == u32(0){
            x = -1.;
            y = 1.;
        }else{
            x = 1.;
            y = -1.;
        }
    }else if in_vertex_index == u32(2){
        x = 1.;
        y = 1.;
    }

    // triangle
    // if in_vertex_index == u32(0){
    //     x = -1.;
    //     y = -1.;
    // }else if in_vertex_index == u32(1){
    //     x = 0.;
    //     y = 1.
    // }else{
    //     x = 1.;
    //     y = -1.;
    // }
    return vec4<f32>(f32(x), f32(y), 0.0, 1.0);
}


@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {

    var newpos = pos.xy / cmd.size.xy; // normalize to 0 - 1

    newpos.x = newpos.x
        //* (cmd.size.x / cmd.size.y)// account for aspect ratio
        //- (cmd.size.x / cmd.size.y / 2.0)
    ;

    newpos.y = newpos.y
        //- 0.5
    ;

    //let dist = length(newpos - cmd.circle_pos) - cmd.circle_rad;

    //newpos += cmd.offset.xy;

    //var col = mix(
    //    mix(vec3(1.0, 0.0, 1.0), vec3(0.0, 0.0, 1.0), -dist / cmd.circle_rad), // inside circle
    //    mix(vec3(0.0), vec3(0.0, 1.0, 0.0), dist), // outside circle
    //smoothstep(-0.003, 0.0, dist));

    //var col: vec3<f32> = mix(mix(vec3(0.0), vec3(1.0), -length(newpos)), vec3(0.0,0.0,1.0), length(newpos));
    var col = mix(vec3(0.0), vec3(1.0), step(0.0, newpos.y - newpos.x));

    return vec4<f32>(col, 1.0);

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