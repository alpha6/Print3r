; generated by Slic3r 1.33.8-prusa3d-linux64 on 2017-03-01 at 16:49:56

; external perimeters extrusion width = 0.50mm
; perimeters extrusion width = 0.50mm
; infill extrusion width = 0.50mm
; solid infill extrusion width = 0.50mm
; top infill extrusion width = 0.50mm
; support material extrusion width = 0.50mm


G28 X Y Z; home all axes
G21 ; set units to millimeters
G90 ; use absolute coordinates
M82 ; use absolute distances for extrusion
G92 E0

M109 S100

G1 Z10 F7800.000
G1 X-23 Y-23
G1 X23 Y-23
G1 X23 Y23
G1 X-23 Y23
G1 Z11
G1 X-23 Y-23
G1 X23 Y-23
G1 X23 Y23
G1 X-23 Y23
G1 Z12
G1 X-23 Y-23
G1 X23 Y-23
G1 X23 Y23
G1 X-23 Y23
G1 Z13
G1 X-23 Y-23
G1 X23 Y-23
G1 X23 Y23
G1 X-23 Y23
G1 Z14
G1 X-23 Y-23
G1 X23 Y-23
G1 X23 Y23
G1 X-23 Y23
G1 Z15

G92 E0
G28   ; home X axis
M104 S0 ; turn off temperature
M140 S0
M84     ; disable motors

; filament used = 39842.6mm (95.8cm3)
; total filament cost = 0.0

; avoid_crossing_perimeters = 1
; bed_shape = 99.4522x10.4528,97.8148x20.7912,95.1057x30.9017,91.3545x40.6737,86.6025x50,80.9017x58.7785,74.3145x66.9131,66.9131x74.3145,58.7785x80.9017,50x86.6025,40.6737x91.3545,30.9017x95.1057,20.7912x97.8148,10.4528x99.4522,0x100,-10.4528x99.4522,-20.7912x97.8148,-30.9017x95.1057,-40.6737x91.3545,-50x86.6025,-58.7785x80.9017,-66.9131x74.3145,-74.3145x66.9131,-80.9017x58.7785,-86.6025x50,-91.3545x40.6737,-95.1057x30.9017,-97.8148x20.7912,-99.4522x10.4528,-100x0,-99.4522x-10.4528,-97.8148x-20.7912,-95.1057x-30.9017,-91.3545x-40.6737,-86.6025x-50,-80.9017x-58.7785,-74.3145x-66.9131,-66.9131x-74.3145,-58.7785x-80.9017,-50x-86.6025,-40.6737x-91.3545,-30.9017x-95.1057,-20.7912x-97.8148,-10.4528x-99.4522,0x-100,10.4528x-99.4522,20.7912x-97.8148,30.9017x-95.1057,40.6737x-91.3545,50x-86.6025,58.7785x-80.9017,66.9131x-74.3145,74.3145x-66.9131,80.9017x-58.7785,86.6025x-50,91.3545x-40.6737,95.1057x-30.9017,97.8148x-20.7912,99.4522x-10.4528,100x0
; bed_temperature = 70
; before_layer_gcode = 
; bridge_acceleration = 0
; bridge_fan_speed = 100
; brim_width = 3
; complete_objects = 0
; cooling = 1
; default_acceleration = 0
; disable_fan_first_layers = 2
; duplicate_distance = 6
; end_gcode = G28   ; home X axis\nM104 S0 ; turn off temperature\nM140 S0\nM84     ; disable motors\n
; extruder_clearance_height = 20
; extruder_clearance_radius = 20
; extruder_offset = 0x0
; extrusion_axis = E
; extrusion_multiplier = 1
; fan_always_on = 0
; fan_below_layer_time = 10
; filament_colour = #3A2C2C
; filament_cost = 900
; filament_density = 0
; filament_diameter = 1.75
; filament_max_volumetric_speed = 0
; filament_notes = ""
; first_layer_acceleration = 0
; first_layer_bed_temperature = 70
; first_layer_extrusion_width = 120%
; first_layer_speed = 30
; first_layer_temperature = 250
; gcode_arcs = 0
; gcode_comments = 0
; gcode_flavor = reprap
; infill_acceleration = 0
; infill_first = 0
; layer_gcode = 
; max_fan_speed = 100
; max_layer_height = 0
; max_print_speed = 80
; max_volumetric_extrusion_rate_slope_negative = 0
; max_volumetric_extrusion_rate_slope_positive = 0
; max_volumetric_speed = 0
; min_fan_speed = 5
; min_layer_height = 0.07
; min_print_speed = 10
; min_skirt_length = 0
; notes = 
; nozzle_diameter = 0.4
; only_retract_when_crossing_perimeters = 1
; ooze_prevention = 0
; output_filename_format = [input_filename_base].gcode
; perimeter_acceleration = 0
; post_process = 
; pressure_advance = 0
; resolution = 0
; retract_before_travel = 2
; retract_layer_change = 0
; retract_length = 2
; retract_length_toolchange = 2
; retract_lift = 0
; retract_lift_above = 0
; retract_lift_below = 0
; retract_restart_extra = 0
; retract_restart_extra_toolchange = 1
; retract_speed = 40
; skirt_distance = 0
; skirt_height = 1
; skirts = 1
; slowdown_below_layer_time = 5
; spiral_vase = 0
; standby_temperature_delta = -5
; start_gcode = G28 X Y Z; home all axes\nG29\n
; temperature = 250
; threads = 2
; toolchange_gcode = 
; travel_speed = 130
; use_firmware_retraction = 0
; use_relative_e_distances = 0
; use_volumetric_e = 0
; variable_layer_height = 1
; wipe = 1
; z_offset = 0
; clip_multipart_objects = 0
; dont_support_bridges = 0
; extrusion_width = 0.5
; first_layer_height = 0.2
; infill_only_where_needed = 0
; interface_shells = 0
; layer_height = 0.2
; raft_layers = 0
; seam_position = aligned
; support_material = 1
; support_material_angle = 45
; support_material_buildplate_only = 0
; support_material_contact_distance = 0.2
; support_material_enforce_layers = 0
; support_material_extruder = 1
; support_material_extrusion_width = 0
; support_material_interface_contact_loops = 0
; support_material_interface_extruder = 1
; support_material_interface_layers = 2
; support_material_interface_spacing = 0.4
; support_material_interface_speed = 100%
; support_material_pattern = rectilinear
; support_material_spacing = 1
; support_material_speed = 60
; support_material_synchronize_layers = 0
; support_material_threshold = 0
; support_material_with_sheath = 1
; support_material_xy_spacing = 50%
; xy_size_compensation = 0
; bottom_solid_layers = 3
; bridge_flow_ratio = 1.1
; bridge_speed = 40
; ensure_vertical_shell_thickness = 0
; external_fill_pattern = rectilinear
; external_perimeter_extrusion_width = 0
; external_perimeter_speed = 70%
; external_perimeters_first = 0
; extra_perimeters = 1
; fill_angle = 45
; fill_density = 100%
; fill_pattern = rectilinear
; gap_fill_speed = 20
; infill_every_layers = 1
; infill_extruder = 1
; infill_extrusion_width = 0
; infill_overlap = 15%
; infill_speed = 70
; overhangs = 1
; perimeter_extruder = 1
; perimeter_extrusion_width = 0
; perimeter_speed = 60
; perimeters = 3
; small_perimeter_speed = 50
; solid_infill_below_area = 70
; solid_infill_every_layers = 0
; solid_infill_extruder = 1
; solid_infill_extrusion_width = 0
; solid_infill_speed = 50
; thin_walls = 1
; top_infill_extrusion_width = 0
; top_solid_infill_speed = 40
; top_solid_layers = 3
