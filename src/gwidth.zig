const std = @import("std");
const unicode = std.unicode;
const testing = std.testing;
const DisplayWidth = @import("DisplayWidth");
const code_point = @import("code_point");

/// the method to use when calculating the width of a grapheme
pub const Method = enum {
    unicode,
    wcwidth,
    no_zwj,
};

/// returns the width of the provided string, as measured by the method chosen
pub fn gwidth(str: []const u8, method: Method, data: *const DisplayWidth.DisplayWidthData) !usize {
    switch (method) {
        .unicode => {
            const dw: DisplayWidth = .{ .data = data };
            return dw.strWidth(str);
        },
        .wcwidth => {
            var total: usize = 0;
            var iter: code_point.Iterator = .{ .bytes = str };
            while (iter.next()) |cp| {
                const w = switch (cp.code) {
                    // undo an override in zg for emoji skintone selectors
                    0x1f3fb...0x1f3ff,
                    => 2,
                    else => data.codePointWidth(cp.code),
                };
                if (w < 0) continue;
                total += @intCast(w);
            }
            return total;
        },
        .no_zwj => {
            var out: [256]u8 = undefined;
            if (str.len > out.len) return error.OutOfMemory;
            const n = std.mem.replacementSize(u8, str, "\u{200D}", "");
            _ = std.mem.replace(u8, str, "\u{200D}", "", &out);
            return gwidth(out[0..n], .unicode, data);
        },
    }
}

test "gwidth: a" {
    const alloc = testing.allocator_instance.allocator();
    const data = try DisplayWidth.DisplayWidthData.init(alloc);
    defer data.deinit();
    try testing.expectEqual(1, try gwidth("a", .unicode, &data));
    try testing.expectEqual(1, try gwidth("a", .wcwidth, &data));
    try testing.expectEqual(1, try gwidth("a", .no_zwj, &data));
}

test "gwidth: emoji with ZWJ" {
    const alloc = testing.allocator_instance.allocator();
    const data = try DisplayWidth.DisplayWidthData.init(alloc);
    defer data.deinit();
    try testing.expectEqual(2, try gwidth("👩‍🚀", .unicode, &data));
    try testing.expectEqual(4, try gwidth("👩‍🚀", .wcwidth, &data));
    try testing.expectEqual(4, try gwidth("👩‍🚀", .no_zwj, &data));
}

test "gwidth: emoji with VS16 selector" {
    const alloc = testing.allocator_instance.allocator();
    const data = try DisplayWidth.DisplayWidthData.init(alloc);
    defer data.deinit();
    try testing.expectEqual(2, try gwidth("\xE2\x9D\xA4\xEF\xB8\x8F", .unicode, &data));
    try testing.expectEqual(1, try gwidth("\xE2\x9D\xA4\xEF\xB8\x8F", .wcwidth, &data));
    try testing.expectEqual(2, try gwidth("\xE2\x9D\xA4\xEF\xB8\x8F", .no_zwj, &data));
}

test "gwidth: emoji with skin tone selector" {
    const alloc = testing.allocator_instance.allocator();
    const data = try DisplayWidth.DisplayWidthData.init(alloc);
    defer data.deinit();
    try testing.expectEqual(2, try gwidth("👋🏿", .unicode, &data));
    try testing.expectEqual(4, try gwidth("👋🏿", .wcwidth, &data));
    try testing.expectEqual(2, try gwidth("👋🏿", .no_zwj, &data));
}
