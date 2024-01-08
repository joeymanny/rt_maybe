@group(0) @binding(0) var<uniform> cmd: MandelCommands;

struct MandelCommands{
    size: vec4<f32>,
    offset: vec4<f32>,
    zoom: f32,
    lod: f32,
    sphere: Sphere
}
struct Sphere{
    pos: vec4<f32>,
    color: vec4<f32>,
    radius: f32,
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

const zoom_base = 1.3;

var<private> lodf: f32;

const a: f32 = 0.249658;
const b: f32 = -10.0235;
const c: f32 = 57.0;

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {

    var newpos = pos.xy / cmd.size.xy; // normalize to 0 - 1

    newpos.x = ((newpos.x - 0.5)    // cartesian coordinates
        * (cmd.size.x / cmd.size.y))// account for aspect ratio
        * pow(zoom_base, cmd.zoom)  // zoom in
    ;

    newpos.y = (newpos.y - 0.5)
        * pow(zoom_base, cmd.zoom)
    ;

    newpos += cmd.offset.xy;

    lodf = max(8.0, a * cmd.zoom * cmd.zoom + b * cmd.zoom + c); // dynamic level of detail based off zoom
    lodf *= cmd.lod;    // the actual requested lod also has an effect

    var mand = f32(mandel(Complex(newpos.x, newpos.y)));
    var mand_val = mand; // how many iterations did it take

    // taking the average of surrounding pixels improves detail at the cost of performance
    // var unit = vec2(1.0) / cmd.size;
    // unit.x *= pow(zoom_base, cmd.zoom);
    // unit.y *= pow(zoom_base, cmd.zoom);
    // mand += f32(mandel(Complex(newpos.x - unit.x, newpos.y)))
    //     + f32(mandel(Complex(newpos.x, newpos.y + unit.y)))
    //     + f32(mandel(Complex(newpos.x + unit.x, newpos.y)))
    //     + f32(mandel(Complex(newpos.x, newpos.y - unit.y)));
    // mand /= 5.0;

    mand /= lodf; // normalize to 0 - 1 (see number of loops in mandel() function)
    // var e: u8 = 1;
    var col = mix(vec3(0.008, 0.0, 0.08), vec3(.03, 0.0, 0.0), mand_val % 5.0 / 4.0); // what color should it be if outside of set
    var background = vec3(0.0);
    col = mix(col, background, step(f32(u32(lodf) - u32(1)), mand_val)); // should it have outside or inside color

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
    while (i < u32(round(lodf))){
        i += u32(1);
        z = mandel_iter(z, c);
        if abs_sq(z) > 4.0 {
            return i;
        }
    }
    return i;
}