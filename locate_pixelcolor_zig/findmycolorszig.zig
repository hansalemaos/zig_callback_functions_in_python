const save_my_colors = *const fn (rgba: c_uint, x: c_ushort, y:
c_ushort, resultdi: usize) void;

export fn find_rgba_colors(save_function: usize, address_pic: usize,
address_colors: usize, width: usize, totallengthpic: usize,
totallengthcolor: usize, resultdi: usize) void {
    @setFloatMode(.optimized);
    const pic: [*]c_uint = @ptrFromInt(address_pic);
    const colors: [*]c_uint = @ptrFromInt(address_colors);
    const save_color_function: save_my_colors = @ptrFromInt(save_function);
    var tmpcolor: c_uint = 0;

    for (0..totallengthcolor) |colorindex| {
        tmpcolor = colors[colorindex];
        for (0..totallengthpic) |picindex| {
            if (pic[picindex] == tmpcolor) {
                save_color_function(tmpcolor,
                @as(c_ushort, @intCast(@divFloor(picindex, width))),
                @as(c_ushort, @intCast(@mod(picindex, width))), resultdi);
            }
        }
    }
}
