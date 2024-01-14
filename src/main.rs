const ZOOM_BASE: f32 = 1.3;

const FALLBACK_RESOLUTION: winit::dpi::PhysicalSize<u32> = winit::dpi::PhysicalSize::new(800, 600);

const LEN: usize = 12;

const NUM_SPHERES: u32 = 2;

const LIGHT_MOVEMENT_STEP: f32 = 1. / 32.;

const DEGREE: f32 = PI / 180.0;

use std::{f32::consts::PI, collections::HashMap, io::Read};

use rand::Rng;
use wgpu::{PipelineLayoutDescriptor, RenderPipelineDescriptor, util::{DeviceExt,}};
use winit::{event::{KeyEvent, ElementState}, keyboard::{KeyCode, Key}};
fn main(){
    let event_loop = winit::event_loop::EventLoop::new().unwrap();
    event_loop.set_control_flow(winit::event_loop::ControlFlow::Poll);
    let primary_size = match event_loop.primary_monitor(){
        Some(v) => v.size(),
        None => FALLBACK_RESOLUTION
    };
    // sure hope nobody has a monitor less than 10 pixels 
    let window = winit::window::WindowBuilder::new()
        // .with_min_inner_size(winit::dpi::PhysicalSize{width,height,})
        .with_inner_size(primary_size)
        .with_title("raytracing")
        .build(&event_loop)
        .unwrap();
    env_logger::init();
    pollster::block_on(run(event_loop, window));
}


async fn run(event_loop: winit::event_loop::EventLoop<()>, window: winit::window::Window) {
    let mut size = window.inner_size();
    size.width = size.width.max(1);
    size.height = size.height.max(1);
    let instance = wgpu::Instance::default();
    let surface = unsafe { instance.create_surface(&window) }.unwrap();
    let adapter = instance.request_adapter(&wgpu::RequestAdapterOptions{
        power_preference: wgpu::PowerPreference::HighPerformance,
        force_fallback_adapter: false,
        compatible_surface: Some(&surface),
    }).await.expect("couldn't find an adapter");
    let (device, queue) = adapter.request_device(&wgpu::DeviceDescriptor{
            label: None,
            features: wgpu::Features::empty(),
            limits: wgpu::Limits::downlevel_defaults()
                .using_resolution(adapter.limits())
        },
        None
    ).await.expect("couldn't find an adequate device");
    let mandel_commands: &mut [f32] = &mut [
        size.width as f32, size.height as f32, 0.0, 0.0, // screen dimensions + 2 unused f32
        0.0, 0.0, 0.0, PI / 2.0, // camera position + fov
        0.0, 1.0, -5.0, 1.0, // light position + controlled by `[`/`]`
    ];
    let mut spheres: Vec<f32> = Vec::from([
        0.0, 0.0, -6.0, 0.25,// sphere position + radius
        0.0, 1.0, 0.0, 0.0,  // sphere color 
        0.0, -0.1, -3.0, 0.1,
        1.0, 0.0, 0.0, 0.0, 
    ]);

    append_random_spheres(&mut spheres, NUM_SPHERES);

    let staging_mandel_commands_buffer = device.create_buffer(&wgpu::BufferDescriptor{
        label: None,
        size: (std::mem::size_of::<f32>() * LEN) as u64,
        usage: wgpu::BufferUsages::COPY_SRC | wgpu::BufferUsages::MAP_WRITE,
        mapped_at_creation: false,
    });
    let mandel_commands_buffer = device.create_buffer_init(&wgpu::util::BufferInitDescriptor{
        label: None,
        contents: bytemuck::cast_slice(mandel_commands),
        usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST

    });
    let staging_spheres_buffer = device.create_buffer(&wgpu::BufferDescriptor{
        label: None,
        size: NUM_SPHERES as u64 * 8 * std::mem::size_of::<f32>() as u64,
        usage: wgpu::BufferUsages::COPY_SRC | wgpu::BufferUsages::MAP_WRITE,
        mapped_at_creation: false,
    });
    let spheres_buffer = device.create_buffer(&wgpu::BufferDescriptor{
        label: None,
        size: NUM_SPHERES as u64 * 8 * std::mem::size_of::<f32>() as u64,
        usage: wgpu::BufferUsages::STORAGE | wgpu::BufferUsages::COPY_DST,
        mapped_at_creation: false,
    });

    let bind_group_layout = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor{
        label: None,
        entries: &[
            wgpu::BindGroupLayoutEntry{
                binding: 0,
                visibility: wgpu::ShaderStages::VERTEX_FRAGMENT,
                ty: wgpu::BindingType::Buffer{
                    ty: wgpu::BufferBindingType::Uniform,
                    has_dynamic_offset: false,
                    min_binding_size: None,
                },
                count: None,
            },
            wgpu::BindGroupLayoutEntry{
                binding: 1,
                visibility: wgpu::ShaderStages::VERTEX_FRAGMENT,
                ty: wgpu::BindingType::Buffer{
                    ty: wgpu::BufferBindingType::Storage { read_only: true },
                    has_dynamic_offset: false,
                    min_binding_size: None,
                },
                count: None,
            },
        ]
    });
    let bind_group = device.create_bind_group(&wgpu::BindGroupDescriptor{
        label: None,
        layout: &bind_group_layout,
        entries: &[
            wgpu::BindGroupEntry{
                binding: 0,
                resource: wgpu::BindingResource::Buffer(wgpu::BufferBinding{
                    buffer: &mandel_commands_buffer,
                    offset: 0,
                    size: None,
                })
            },
            wgpu::BindGroupEntry{
                binding: 1,
                resource: wgpu::BindingResource::Buffer(wgpu::BufferBinding{
                    buffer: &spheres_buffer,
                    offset: 0,
                    size: None,
                })
            },
        ]
    });
    // ! REMOVE THIS!!!!!!!!!!!!!!!!!
    let path = std::path::Path::new("./src/shader.wgsl");
    let mut file = std::fs::File::open(path).expect("this is a rapid developement binary and requires a shader.wgsl to be present in the src directory");
    let mut shader_string = String::new();
    file.read_to_string(&mut shader_string).expect("couldn't read src/shader.wgsl to a string");
    let shader = device.create_shader_module(wgpu::ShaderModuleDescriptor{
        label: None,
        source: wgpu::ShaderSource::Wgsl(std::borrow::Cow::Borrowed(&shader_string))
    });
    let pipeline_layout = device.create_pipeline_layout(&PipelineLayoutDescriptor{
        label: None,
        bind_group_layouts: &[&bind_group_layout],
        push_constant_ranges: &[],
    });
    let swapchain_capabilities = surface.get_capabilities(&adapter);
    let swapchain_format = swapchain_capabilities.formats[0];
    let render_pipeline = device.create_render_pipeline(&RenderPipelineDescriptor{
        label: None,
        layout: Some(&pipeline_layout),
        vertex: wgpu::VertexState {
            module: &shader,
            entry_point: "vs_main",
            buffers: &[]
        },
        fragment: Some(wgpu::FragmentState {
            module: &shader,
            entry_point: "fs_main",
            targets: &[Some(swapchain_format.into())]
        }),
        primitive: wgpu::PrimitiveState::default(),
        depth_stencil: None,
        multisample: wgpu::MultisampleState::default(),
        multiview: None,
    });
    let mut config = wgpu::SurfaceConfiguration{
        usage: wgpu::TextureUsages::RENDER_ATTACHMENT,
        format: swapchain_format,
        width: size.width,
        height: size.height,
        present_mode: wgpu::PresentMode::Fifo,
        alpha_mode: swapchain_capabilities.alpha_modes[0],
        view_formats: vec![],
    };
    surface.configure(&device, &config);

    let mut kb: HashMap<KeyCode, ElementState> = std::collections::HashMap::new();

    let mut select_buf = String::new();
    event_loop.run(
    move |event, target|{
        // so they get cleaned up since run() never returns
        let _ = (&instance, &adapter, &shader, &pipeline_layout);
        let mut is_mandel_update = false;
        let mut is_spheres_update = false;
        match event {
        winit::event::Event::WindowEvent{event: v, ..} => {
        match v {
            winit::event::WindowEvent::Resized(new_size) => {
                config.width = new_size.width.max(1);
                config.height = new_size.height.max(1);
                surface.configure(&device, &config);

                mandel_commands[0] = new_size.width as f32;
                mandel_commands[1] = new_size.height as f32;
                is_mandel_update = true;

                window.request_redraw();
            }
            winit::event::WindowEvent::RedrawRequested =>{
                let frame = surface
                    .get_current_texture()
                    .expect("coulnd't get next swap chain texture");
                let view = frame
                    .texture
                    .create_view(&wgpu::TextureViewDescriptor::default());
                let mut encoder =
                    device.create_command_encoder(&wgpu::CommandEncoderDescriptor{label: None});
                {
                    let mut rpass =
                        encoder.begin_render_pass(&wgpu::RenderPassDescriptor{
                            label: None,
                            color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                                view: &view,
                                resolve_target: None,
                                ops: wgpu::Operations {
                                    load: wgpu::LoadOp::Clear(wgpu::Color::BLUE),
                                    store: wgpu::StoreOp::Store,
                                }
                            })],
                            ..Default::default()
                        });
                        rpass.set_bind_group(0, &bind_group, &[]);
                        rpass.set_pipeline(&render_pipeline);
                        rpass.draw(0..3, 0..2);
                }
                queue.submit(Some(encoder.finish()));
                frame.present();
            },
            winit::event::WindowEvent::CloseRequested => target.exit(),
            winit::event::WindowEvent::KeyboardInput { event: KeyEvent{ physical_key: winit::keyboard::PhysicalKey::Code(key), state, repeat, .. }, .. } =>{
                kb.insert(key, state);
                match (key, state){
                    (KeyCode::Space, ElementState::Pressed) if !repeat =>{
                            spheres.clear();
                            append_random_spheres(&mut spheres, NUM_SPHERES);
                            is_spheres_update = true;
                    },
                    (KeyCode::KeyQ, ElementState::Pressed) if !repeat => {
                        spheres.truncate(spheres.len() - 8);
                        spheres.append(&mut vec![-0.5 - f32::EPSILON * 32., 0.0, -10., 0.5, 0.0, 0.0, 1.0, 0.0]);
                        is_spheres_update = true;
                    }
                    _ => (),
                }
                if let ElementState::Pressed = state{
                    if let Some(&ElementState::Pressed) = kb.get(&KeyCode::AltLeft){
                        match key{
                            KeyCode::Digit0 => select_buf.push('0'),
                            KeyCode::Digit1 => select_buf.push('1'),
                            KeyCode::Digit2 => select_buf.push('2'),
                            KeyCode::Digit3 => select_buf.push('3'),
                            KeyCode::Digit4 => select_buf.push('4'),
                            KeyCode::Digit5 => select_buf.push('5'),
                            KeyCode::Digit6 => select_buf.push('6'),
                            KeyCode::Digit7 => select_buf.push('7'),
                            KeyCode::Digit8 => select_buf.push('8'),
                            KeyCode::Digit9 => select_buf.push('9'),
                            _=>()
                        }
                    }
                }else{ //key just released
                    if let KeyCode::AltLeft = key{
                        println!("{}",select_buf);
                        if let Ok(mut v) = select_buf.parse::<u32>(){
                            v *= 8; // six floats per sphere
                            v += 4; // get to color part
                            if let Some(r) = spheres.get_mut(v as usize){
                                *r = 1.0;
                                is_spheres_update = true;
                            }
                            v += 1;
                            if let Some(r) = spheres.get_mut(v as usize){
                                *r = 0.0;
                                is_spheres_update = true;
                            }
                            v += 1;
                            if let Some(r) = spheres.get_mut(v as usize){
                                *r = 0.0;
                                is_spheres_update = true;
                            }
                        }
                        select_buf.clear();
                    }
                }
                // kb.insert(key, state);
            },

            // winit::event::WindowEvent::KeyboardInput{event: winit::keyboard::Keyevent{..}, ..} =>(),
            _ => (),
            }
        },
        winit::event::Event::AboutToWait =>{
            for (key, value) in kb.iter(){
                if let ElementState::Released = value{
                    continue;
                }
                let mut delta = (0., 0., 0., 0.0);
                if let KeyCode::KeyO = key{
                    delta.2 += -LIGHT_MOVEMENT_STEP;
                }
                if let KeyCode::KeyL = key{
                    delta.2 += LIGHT_MOVEMENT_STEP;
                }
                if let KeyCode::KeyK = key{
                    delta.0 += -LIGHT_MOVEMENT_STEP;
                }
                if let KeyCode::Semicolon = key{
                    delta.0 += LIGHT_MOVEMENT_STEP;
                }
                if let KeyCode::KeyJ = key{
                    delta.1 += -LIGHT_MOVEMENT_STEP;
                }
                if let KeyCode::KeyU = key{
                    delta.1 += LIGHT_MOVEMENT_STEP;
                }
                if let KeyCode::Minus= key{
                    delta.3 += DEGREE;
                }
                if let KeyCode::Equal = key{
                    delta.3 -= DEGREE;
                }
                if let KeyCode::BracketRight = key{
                    mandel_commands[11] *= 1.01;
                    println!("arb: {}", mandel_commands[11]);
                }
                if let KeyCode::BracketLeft = key{
                    mandel_commands[11] /= 1.01;
                    println!("arb: {}", mandel_commands[11]);
                }


                    //8,9,10
                mandel_commands[8] += delta.0;
                mandel_commands[9] += delta.1;
                mandel_commands[10] += delta.2;
                mandel_commands[7] = (mandel_commands[7] + delta.3).max(f32::EPSILON);
                is_mandel_update = true;
                // println!("x:\t{}\ny:\t{}\nz:\t{}\nzoom:\t{}\n", mandel_commands[8], mandel_commands[9], mandel_commands[10], mandel_commands[7]);

            }
        },
        _=>(),
        }
        if is_mandel_update{
            // dbg!(&mandel_commands);
            let (sender, receiver) = flume::bounded(1);
            let slice = staging_mandel_commands_buffer.slice(..);
            slice.map_async(wgpu::MapMode::Write, move |v| sender.send(v).unwrap());
            device.poll(wgpu::Maintain::Wait);

            if let Ok(Ok(())) = receiver.recv(){
                let mut mapped = slice.get_mapped_range_mut();
                mapped.clone_from_slice(bytemuck::cast_slice(mandel_commands));
                drop(mapped);
                staging_mandel_commands_buffer.unmap();
                let mut encoder = device.create_command_encoder(&Default::default());
                encoder.copy_buffer_to_buffer(
                    &staging_mandel_commands_buffer, 0,
                    &mandel_commands_buffer, 0,
                    (std::mem::size_of::<f32>() * LEN) as u64,
                );
                queue.submit(Some(encoder.finish()));
            }
            window.request_redraw();
        }
        if is_spheres_update{
            // dbg!(&mandel_commands);
            let (sender, receiver) = flume::bounded(1);
            let slice = staging_spheres_buffer.slice(..);
            slice.map_async(wgpu::MapMode::Write, move |v| sender.send(v).unwrap());
            device.poll(wgpu::Maintain::Wait);

            if let Ok(Ok(())) = receiver.recv(){
                let mut mapped = slice.get_mapped_range_mut();
                mapped.clone_from_slice(bytemuck::cast_slice(&spheres));
                drop(mapped);
                staging_spheres_buffer.unmap();
                let mut encoder = device.create_command_encoder(&Default::default());
                encoder.copy_buffer_to_buffer(
                    &staging_spheres_buffer, 0,
                    &spheres_buffer, 0,
                    (std::mem::size_of::<f32>() * (NUM_SPHERES * 8) as usize) as u64,
                );
                queue.submit(Some(encoder.finish()));
            }
            window.request_redraw();
        }
    })
    .unwrap();
}
 fn append_random_spheres(spheres: &mut Vec<f32>, n: u32){
    (0..n).into_iter().for_each(|_|{
        let mut r = rand::thread_rng();
        let mut e = vec![];
        for _ in 0..7{e.push(r.gen::<f32>())}
        let z = -2.0 + (-e[0] * 10.0);
        let x = (e[1] * 4.0) - 2.0;
        let y = (e[2] * 4.0) - 2.0;
        let rad = e[3];
        let r = e[4].max(0.3);
        let g = e[5].max(0.3);
        let b = e[6].max(0.3);
        spheres.append(&mut dbg!(vec![x,y,z,rad,r,g,b,0.]));
        
    });
 }